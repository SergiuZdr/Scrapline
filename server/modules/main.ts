/**
 * Scrapline's Nakama runtime modules.
 *
 * Nakama gives us accounts, storage, leaderboards and tournaments out of the box, so
 * this file is deliberately thin: it stores defence squads, hands out opponents, and
 * accepts match submissions.
 *
 * ## The verification split, and why it looks like this
 *
 * The battle simulation is GDScript. Nakama's runtime is TypeScript. Neither can run
 * the other, so this module CANNOT recompute a battle — and re-implementing the
 * simulation here would be catastrophic: two implementations of a deterministic sim
 * drift, and the day they disagree every honest player starts getting rejected.
 *
 * So submissions land in a `pending` state and a **separate headless Godot worker**
 * (see `server/verifier/`) consumes them, re-runs the real simulation, and confirms or
 * revokes. One implementation of the rules, ever.
 *
 * What this module does enforce, because it can:
 *   - the submitter is who they say they are (Nakama's session, not a client field)
 *   - the defender's squad and doctrine come from SERVER storage, never the payload
 *   - rate limits, so a client cannot submit a hundred matches a minute
 *   - rating changes are computed here, from stored ratings
 */

// --- Collections -------------------------------------------------------------

const DEFENCE_COLLECTION = "pvp_defence";
const PENDING_COLLECTION = "pvp_pending";
/**
 * Where decided matches go. They used to stay in the pending collection, which meant the
 * worker's scan -- which reads a page of storage, not a page of *pending* records --
 * stopped reaching new work once a hundred old verdicts sat in front of it. Submissions
 * queued, nothing was claimed, and nothing reported an error.
 */
const DECIDED_COLLECTION = "pvp_decided";
const PROFILE_COLLECTION = "profile";
const BOSS_COLLECTION = "boss";
/** The open encounter every guild's pool is instantiated from. */
const BOSS_TEMPLATE_KEY = "template";
/** Key prefix for a player with no guild, who fights their own copy. */
const SOLO_SCOPE = "solo:";
const PURCHASE_COLLECTION = "purchases";

/** Members per guild. Small on purpose: a colossus needs a few dozen attempts to fall,
 * which a guild of this size can manage in a week without anybody carrying it alone. */
const GUILD_LIMIT = 30;

/**
 * Environment key that honours receipts from the development stub.
 *
 * **Off unless explicitly switched on.** With it on, anyone can mint premium currency by
 * sending a made-up order id, so it is opt-in through the runtime environment rather
 * than a constant somebody has to remember to flip before shipping. See the compose
 * file, where it is set for local development only.
 */
const DEV_PURCHASE_ENV = "SCRAPLINE_ALLOW_DEV_PURCHASES";


function devPurchasesAllowed(ctx: nkruntime.Context): boolean {
  return String(ctx.env[DEV_PURCHASE_ENV] || "") === "true";
}
const CONTENT_COLLECTION = "content";
const RANKED_LEADERBOARD = "ranked";

/** Storage owned by the server rather than any player. */
const SYSTEM_USER = "00000000-0000-0000-0000-000000000000";

/** Must match `Ranked.BASE_RATING` in the client. */
const BASE_RATING = 1000;

/** Elo K-factors, tapering as an account settles. **These must match `Ranked` on the
 * client exactly.** They did not at first — the client showed a new player +24 and the
 * server applied +10, so every early match ended with the screen and the ladder
 * disagreeing about the same fight. Matches played comes from the ladder record's
 * `numScore`, so nothing extra has to be stored to know it. */
const K_PLACEMENT = 48;
const K_SETTLING = 32;
const K_STABLE = 20;
const PLACEMENT_MATCHES = 10;

/** Submission payload versions this server will queue. See `sim/battle_submission.gd`. */
const SUPPORTED_FORMATS = [2];

/** Matches a client may submit per window, and the window in seconds. */
const SUBMIT_LIMIT = 20;
const SUBMIT_WINDOW_SEC = 300;
const RATE_LIMIT_KEY = "submit_rate";
/**
 * Rate counters live in their OWN collection. Sharing the queue's collection meant one
 * counter per player sitting in front of the worker's scan window -- harmless at three
 * players, and a queue that silently stops being drained at a few hundred.
 */
const RATE_COLLECTION = "pvp_rate";

interface DefenceRecord {
  name: string;
  rating: number;
  power: number;
  squad: unknown[];
  doctrine: unknown[];
  updatedAt: number;
}

interface PendingRecord {
  submission: unknown;
  submitter: string;
  receivedAt: number;
  state: "pending" | "claimed" | "accepted" | "rejected";
  claimedAt?: number;
  decidedAt?: number;
  verdict?: string;
  delta?: number;
  damage?: number;
  score?: number;
}

interface SubmissionPayload {
  format: number;
  setup: Record<string, unknown>;
  orders: unknown[];
  claimed: { winner: number; cycles: number; hash: string };
  context: string;
}

// --- Entry point -------------------------------------------------------------

function InitModule(
  _ctx: nkruntime.Context,
  logger: nkruntime.Logger,
  nk: nkruntime.Nakama,
  initializer: nkruntime.Initializer,
): void {
  initializer.registerRpc("publish_defence", rpcPublishDefence);
  initializer.registerRpc("find_opponents", rpcFindOpponents);
  initializer.registerRpc("submit_match", rpcSubmitMatch);
  initializer.registerRpc("sync_profile", rpcSyncProfile);
  initializer.registerRpc("sync_content", rpcSyncContent);
  initializer.registerRpc("publish_content", rpcPublishContent);
  initializer.registerRpc("boss_state", rpcBossState);
  initializer.registerRpc("open_boss", rpcOpenBoss);
  initializer.registerRpc("validate_purchase", rpcValidatePurchase);
  initializer.registerRpc("guild_create", rpcGuildCreate);
  initializer.registerRpc("guild_list", rpcGuildList);
  initializer.registerRpc("guild_join", rpcGuildJoin);
  initializer.registerRpc("guild_leave", rpcGuildLeave);
  initializer.registerRpc("guild_state", rpcGuildState);
  initializer.registerRpc("tournament_state", rpcTournamentState);
  initializer.registerRpc("tournament_join", rpcTournamentJoin);
  initializer.registerRpc("open_tournament", rpcOpenTournament);

  // Worker endpoints. Not for clients -- see `requireWorker`.
  initializer.registerRpc("worker_claim", rpcWorkerClaim);
  initializer.registerRpc("worker_verdict", rpcWorkerVerdict);

  // Ranked ladder. Nakama resets it on the schedule, so seasons cost no code.
  //
  // AUTHORITATIVE. A non-authoritative leaderboard lets a client write its own score,
  // which would make the whole verification pipeline decorative -- a cheat would not
  // need to forge a battle, it could just post a rating.
  try {
    // The enum members, not the strings they look like: Nakama wants "descending",
    // and the "desc" this used to pass was rejected -- inside a try/catch, so the
    // leaderboard was simply never created and nothing said so.
    nk.leaderboardCreate(
      RANKED_LEADERBOARD, true, nkruntime.SortOrder.DESCENDING, nkruntime.Operator.SET,
      "0 0 1 * *", null, true);
  } catch (_error) {
    // Already exists. Creating a leaderboard is idempotent in intent, not in API.
  }

  logger.info("scrapline modules loaded");
}

// --- Defences ----------------------------------------------------------------

/** Stores the caller's squad and doctrine as the thing other players fight. */
const rpcPublishDefence: nkruntime.RpcFunction = (ctx, logger, nk, payload) => {
  const userId = requireUser(ctx);
  const body = JSON.parse(payload || "{}") as Partial<DefenceRecord>;

  if (!Array.isArray(body.squad) || body.squad.length === 0) {
    throw new Error("a defence needs a squad");
  }
  if (body.squad.length > 6) {
    throw new Error("a squad is at most six constructs");
  }

  const record: DefenceRecord = {
    name: String(body.name || "Reclaimer").slice(0, 24),
    rating: ratingOf(nk, userId),
    power: clampInt(body.power, 1, 100000),
    squad: body.squad,
    doctrine: Array.isArray(body.doctrine) ? body.doctrine.slice(0, 12) : [],
    updatedAt: Math.floor(Date.now() / 1000),
  };

  // A player with no ladder record does not exist to `find_opponents`, because the
  // ladder is what defines "near in rating". Publishing a defence is the moment they
  // join, so the record is created here -- without it the first player to open Ranked
  // sees an empty list, and so does everyone after them.
  ensureLadderRecord(nk, userId, record.name, record.rating);

  nk.storageWrite([{
    collection: DEFENCE_COLLECTION,
    key: "current",
    userId,
    value: record as unknown as { [key: string]: unknown },
    // Readable by everyone: a defence exists precisely so other players can fetch and
    // fight it. Writable only by the owner and the server.
    permissionRead: 2,
    permissionWrite: 1,
  }]);

  logger.debug("defence published for %s", userId);
  return JSON.stringify({ ok: true });
};

/**
 * Opponents near the caller's rating.
 *
 * Uses the leaderboard rather than scanning storage: it is already sorted, already
 * indexed, and already the thing that defines "near in rating".
 */
const rpcFindOpponents: nkruntime.RpcFunction = (ctx, _logger, nk, payload) => {
  const userId = requireUser(ctx);
  const body = JSON.parse(payload || "{}") as { count?: number };
  const count = clampInt(body.count, 1, 10);

  // `leaderboardRecordsHaystack` returns the records SURROUNDING a player -- the ones
  // nearest them in rating. `leaderboardRecordsList` with an owner id returns only that
  // player's own record, which is what made this come back empty every time.
  const around = nk.leaderboardRecordsHaystack(
    RANKED_LEADERBOARD, userId, count * 4, "", 0);
  const candidates = (around.records || [])
    .filter((record) => record.ownerId !== userId)
    .slice(0, count);

  const out = [];
  for (const record of candidates) {
    const stored = nk.storageRead([{
      collection: DEFENCE_COLLECTION, key: "current", userId: record.ownerId!,
    }]);
    if (stored.length === 0) continue;
    const defence = stored[0].value as unknown as DefenceRecord;
    out.push({
      id: record.ownerId,
      name: defence.name,
      rating: record.score,
      power: defence.power,
      squad: defence.squad,
      // The defender's OWN doctrine. Never anything the attacker sends, or an attacker
      // could hand their opponent a deliberately useless one.
      doctrine: defence.doctrine,
      bot: false,
    });
  }
  // The caller's own standing travels with the list. It is what makes the server the
  // authority in practice rather than only in principle: the client shows a predicted
  // rating the moment a match ends, and adopts this one as soon as it hears back.
  const own = ownRecord(nk, userId);
  return JSON.stringify({
    opponents: out,
    self: {
      rating: own === null ? BASE_RATING : Number(own.score),
      matches: own === null ? 0 : Number(own.numScore) || 0,
    },
  });
};

// --- Match submission --------------------------------------------------------

/**
 * Accepts a battle for verification. The result is NOT applied here — it is queued for
 * the Godot verifier, which re-runs the simulation and confirms or revokes.
 */
const rpcSubmitMatch: nkruntime.RpcFunction = (ctx, logger, nk, payload) => {
  const userId = requireUser(ctx);
  const body = JSON.parse(payload || "{}") as SubmissionPayload;

  // Must track `BattleSubmission.FORMAT_VERSION` in the client. Left at 1 when the
  // client moved to 2, this refused every submission the game sent — with an error the
  // client logged and nothing else surfaced.
  if (SUPPORTED_FORMATS.indexOf(body.format) < 0) {
    throw new Error(`unsupported submission format ${body.format}`);
  }
  if (!body.setup || !Array.isArray(body.orders)) {
    throw new Error("malformed submission");
  }
  if (!rateLimitOk(nk, userId)) {
    throw new Error("too many submissions; slow down");
  }

  const matchId = nk.uuidv4();
  nk.storageWrite([{
    collection: PENDING_COLLECTION,
    key: matchId,
    userId,
    value: {
      submission: body as unknown as { [key: string]: unknown },
      submitter: userId,
      receivedAt: Math.floor(Date.now() / 1000),
      state: "pending",
    },
    // Server-only. A client must never be able to read or edit the queue it is in.
    permissionRead: 0,
    permissionWrite: 0,
  }]);

  logger.info("match %s queued for verification from %s", matchId, userId);
  return JSON.stringify({ ok: true, matchId, state: "pending" });
};

// --- Live content ------------------------------------------------------------

/**
 * The current balance patch. **Readable by anyone, including the verification worker**,
 * because the worker has to run exactly the content the client ran or every honest
 * submission fails.
 *
 * This is the cheapest content pipeline a live game can have: rebalancing a part, or
 * adding a whole new Battlefield Condition for a season, is one JSON object and no store
 * review.
 */
const rpcSyncContent: nkruntime.RpcFunction = (_ctx, _logger, nk, _payload) => {
  const stored = nk.storageRead([{
    collection: CONTENT_COLLECTION, key: "current", userId: SYSTEM_USER,
  }]);
  if (stored.length === 0) return JSON.stringify({ patch: null });
  return JSON.stringify({ patch: stored[0].value });
};

/**
 * Publishes a patch. Worker-only — a client that could write this could rewrite the
 * game's balance for everyone, which is a much bigger prize than winning one match.
 */
const rpcPublishContent: nkruntime.RpcFunction = (ctx, logger, nk, payload) => {
  requireWorker(ctx);
  const patch = JSON.parse(payload || "{}") as { [key: string]: unknown };
  if (typeof patch.version !== "number") throw new Error("a patch needs a version");

  nk.storageWrite([{
    collection: CONTENT_COLLECTION, key: "current", userId: SYSTEM_USER,
    value: patch, permissionRead: 2, permissionWrite: 0,
  }]);
  logger.info("content patch v%d published", patch.version);
  return JSON.stringify({ ok: true, version: patch.version });
};

// --- Tournaments -------------------------------------------------------------

/**
 * Scheduled tournaments, using **Nakama's own** — which ships the schedule, the join
 * requirement, the attempt limit and the record table. The plan budgeted a week for
 * tournaments; almost all of that week is this one API.
 *
 * Every entrant fights an identical generated challenge (see `tournament.gd`), so the
 * ranking compares squad building rather than who drew the kinder opponent. Scores are
 * written **only** from a worker verdict.
 */
const rpcOpenTournament: nkruntime.RpcFunction = (ctx, logger, nk, payload) => {
  requireWorker(ctx);
  const body = JSON.parse(payload || "{}") as {
    id?: string; title?: string; description?: string;
    durationHours?: number; attempts?: number;
  };
  if (!body.id) throw new Error("a tournament id is required");

  const duration = clampInt(body.durationHours, 1, 720) * 3600;
  const startTime = Math.floor(Date.now() / 1000);
  // An explicit END TIME, not just a duration. `duration` is the length of a reset
  // cycle; leaving endTime at 0 means "never ends", which made every tournament report
  // zero hours remaining and the screen say nothing was running while one was.
  const endTime = startTime + duration;
  try {
    nk.tournamentCreate(
      body.id, true, nkruntime.SortOrder.DESCENDING, nkruntime.Operator.BEST,
      duration, null, {}, String(body.title || "Proving Ground"),
      String(body.description || ""), 0, startTime, endTime,
      0, clampInt(body.attempts, 1, 20), true, true);
  } catch (_error) {
    // Already exists. Creating one is idempotent in intent, not in API.
  }

  logger.info("tournament %s opened", body.id);
  return JSON.stringify({ ok: true, id: body.id });
};


/** The open tournament, the caller's standing in it, and the top of the table. */
const rpcTournamentState: nkruntime.RpcFunction = (ctx, _logger, nk, payload) => {
  const userId = requireUser(ctx);
  const body = JSON.parse(payload || "{}") as { id?: string };
  const id = String(body.id || "");

  // The time arguments are FILTERS, not a range to ignore: passing 0 for both asked for
  // tournaments ending at the epoch, and the screen said "nothing is running" while one
  // was. Left undefined, they filter nothing.
  const found = id
    ? nk.tournamentsGetId([id])
    : (nk.tournamentList(undefined, undefined, undefined, undefined, 10).tournaments || []);
  if (found.length === 0) return JSON.stringify({ tournament: null });
  // The one ending soonest among those still running: with several open, the useful
  // answer is the one a player has least time left to enter.
  const now = Math.floor(Date.now() / 1000);
  const live = found.filter((entry) => Number(entry.endTime || 0) > now);
  const tournament = (live.length > 0 ? live : found)
    .sort((a, b) => Number(a.endTime || 0) - Number(b.endTime || 0))[0];

  const records = nk.tournamentRecordsList(tournament.id, [userId], 20);
  const own = (records.ownerRecords || [])[0];

  return JSON.stringify({
    tournament: {
      id: tournament.id,
      title: tournament.title,
      description: tournament.description,
      start_time: Number(tournament.startTime) || 0,
      end_time: Number(tournament.endTime) || 0,
      max_attempts: Number(tournament.maxNumScore) || 0,
      size: Number(tournament.size) || 0,
    },
    own: own === undefined ? null : {
      score: Number(own.score) || 0,
      attempts: Number(own.numScore) || 0,
      rank: Number(own.rank) || 0,
    },
    top: (records.records || []).map((record) => ({
      name: record.username, score: Number(record.score) || 0, rank: Number(record.rank) || 0,
    })),
  });
};


/**
 * Enters the caller. Nakama enforces the attempt limit from here on, which is the point
 * of using its tournaments rather than a leaderboard with rules bolted on.
 */
const rpcTournamentJoin: nkruntime.RpcFunction = (ctx, logger, nk, payload) => {
  const userId = requireUser(ctx);
  const body = JSON.parse(payload || "{}") as { id?: string };
  if (!body.id) throw new Error("a tournament id is required");

  nk.tournamentJoin(body.id, userId, ctx.username || "Reclaimer");
  logger.info("%s entered tournament %s", userId, body.id);
  return JSON.stringify({ ok: true });
};


/** Records a verified attempt. `BEST` operator, so only an improvement counts. */
function applyTournamentScore(
  nk: nkruntime.Nakama, logger: nkruntime.Logger,
  tournamentId: string, userId: string, score: number,
): number {
  if (score <= 0) return 0;
  try {
    nk.tournamentRecordWrite(tournamentId, userId, "", score, 0, {});
    logger.info("tournament %s: %s scored %d", tournamentId, userId, score);
    return score;
  } catch (error) {
    // Most often "not joined" or "no attempts left" -- both are the tournament working.
    logger.warn("tournament %s rejected a score for %s", tournamentId, userId);
    return 0;
  }
}

// --- Guilds ------------------------------------------------------------------

/**
 * Guilds are **Nakama groups**. Membership, roles, join requests and the invariants
 * around them already exist in the server; re-implementing them on top of storage would
 * be a week of work and a fresh set of bugs to find in production.
 *
 * Open by default: an approval queue on an empty game means a player who clicks Join
 * waits days for nobody to answer. Closed guilds are worth having once there are enough
 * players for exclusivity to mean something, which is not now.
 */
const rpcGuildCreate: nkruntime.RpcFunction = (ctx, logger, nk, payload) => {
  const userId = requireUser(ctx);
  const body = JSON.parse(payload || "{}") as { name?: string; description?: string };
  const name = String(body.name || "").trim();

  if (name.length < 3 || name.length > 24) {
    throw new Error("a guild name is 3 to 24 characters");
  }
  if (userGuild(nk, userId) !== null) {
    throw new Error("you are already in a guild");
  }

  const group = nk.groupCreate(
    userId, name, userId, "en", String(body.description || "").slice(0, 160),
    "", true, { colossus: {} }, GUILD_LIMIT);

  logger.info("guild %s created by %s", name, userId);
  return JSON.stringify({ ok: true, guild: describeGroup(group) });
};


/** Guilds to join, biggest first — an empty one is the least useful thing to offer. */
const rpcGuildList: nkruntime.RpcFunction = (_ctx, _logger, nk, payload) => {
  const body = JSON.parse(payload || "{}") as { search?: string; count?: number };
  const listed = nk.groupsList(
    String(body.search || ""), "", true, undefined, clampInt(body.count, 1, 50));

  const out = (listed.groups || [])
    .map(describeGroup)
    .sort((a, b) => b.members - a.members);
  return JSON.stringify({ guilds: out });
};


const rpcGuildJoin: nkruntime.RpcFunction = (ctx, logger, nk, payload) => {
  const userId = requireUser(ctx);
  const body = JSON.parse(payload || "{}") as { guildId?: string };
  if (!body.guildId) throw new Error("a guild id is required");
  if (userGuild(nk, userId) !== null) throw new Error("you are already in a guild");

  nk.groupUserJoin(body.guildId, userId, ctx.username || "Reclaimer");
  logger.info("%s joined guild %s", userId, body.guildId);
  return JSON.stringify({ ok: true });
};


const rpcGuildLeave: nkruntime.RpcFunction = (ctx, _logger, nk, _payload) => {
  const userId = requireUser(ctx);
  const guild = userGuild(nk, userId);
  if (guild === null) throw new Error("you are not in a guild");

  nk.groupUserLeave(guild.id, userId, "");
  return JSON.stringify({ ok: true });
};


/** The caller's guild and its roster, with each member's ladder rating. */
const rpcGuildState: nkruntime.RpcFunction = (ctx, _logger, nk, _payload) => {
  const userId = requireUser(ctx);
  const guild = userGuild(nk, userId);
  if (guild === null) return JSON.stringify({ guild: null });

  const users = nk.groupUsersList(guild.id, GUILD_LIMIT);
  const members = (users.groupUsers || []).map((entry) => ({
    id: entry.user.userId,
    name: entry.user.displayName || entry.user.username,
    // 0 superadmin, 1 admin, 2 member — the founder is 0, which the UI shows as a mark
    // rather than a permission, since nothing here is gated on it yet.
    role: entry.state,
    rating: ratingOf(nk, String(entry.user.userId)),
  }));
  members.sort((a, b) => b.rating - a.rating);

  return JSON.stringify({ guild: describeGroup(guild), members });
};


function describeGroup(group: nkruntime.Group): {
  id: string; name: string; description: string; members: number; open: boolean;
} {
  return {
    id: group.id,
    name: group.name,
    description: group.description || "",
    members: group.edgeCount || 0,
    open: group.open === true,
  };
}


/** The caller's guild, or null. One guild per player: splitting a small population
 * across several memberships makes every one of them feel empty. */
function userGuild(nk: nkruntime.Nakama, userId: string): nkruntime.Group | null {
  try {
    const listed = nk.userGroupsList(userId, 2);
    const groups = listed.userGroups || [];
    return groups.length > 0 ? (groups[0].group || null) : null;
  } catch (_error) {
    return null;
  }
}

// --- Purchases ---------------------------------------------------------------

/**
 * Validates a receipt and records it, exactly once.
 *
 * **The order id is the replay key.** A captured receipt sent a hundred times must grant
 * once, and the check has to live here rather than on the client, where a determined
 * player owns both sides of the conversation.
 *
 * Real store validation (Google Play's `purchases.products.get`) plugs in below where
 * `verifyWithStore` is stubbed. It needs a service account and a signed build, neither
 * of which exists yet — so a receipt marked `real: false` is accepted only when the
 * server is explicitly running in development mode, and refused otherwise. That flag is
 * the difference between a test build and free premium currency for everyone.
 */
const rpcValidatePurchase: nkruntime.RpcFunction = (ctx, logger, nk, payload) => {
  const userId = requireUser(ctx);
  const body = JSON.parse(payload || "{}") as {
    product?: string; order?: string; token?: string; real?: boolean;
  };

  if (!body.product || !body.order) {
    return JSON.stringify({ valid: false, reason: "a receipt needs a product and an order id" });
  }
  if (body.real !== true && !devPurchasesAllowed(ctx)) {
    return JSON.stringify({ valid: false, reason: "development receipts are not accepted here" });
  }
  if (body.real === true && !verifyWithStore(body.product, String(body.token || ""))) {
    logger.warn("purchase %s failed store validation for %s", body.order, userId);
    return JSON.stringify({ valid: false, reason: "the store did not recognise this purchase" });
  }

  // Keyed on the order id, under the SYSTEM user: a per-player key would let the same
  // receipt be redeemed once on each of a hundred accounts.
  const existing = nk.storageRead([{
    collection: PURCHASE_COLLECTION, key: body.order, userId: SYSTEM_USER,
  }]);
  if (existing.length > 0) {
    const owner = String((existing[0].value as { userId?: string }).userId || "");
    logger.info("purchase %s replayed by %s (owned by %s)", body.order, userId, owner);
    return JSON.stringify({ valid: true, duplicate: true, owner });
  }

  nk.storageWrite([{
    collection: PURCHASE_COLLECTION, key: body.order, userId: SYSTEM_USER,
    value: {
      userId, product: body.product, real: body.real === true,
      at: Math.floor(Date.now() / 1000),
    },
    permissionRead: 0, permissionWrite: 0,
  }]);

  logger.info("purchase %s validated for %s (%s)", body.order, userId, body.product);
  return JSON.stringify({ valid: true, duplicate: false });
};

/**
 * Where Google Play's Developer API call goes.
 *
 * Returning `true` unconditionally would make every forged receipt valid, so it returns
 * FALSE until it is implemented: an unimplemented validator that accepts everything is
 * worse than no validator, because it looks like protection.
 */
function verifyWithStore(_productId: string, _token: string): boolean {
  return false;
}

// --- The co-op boss ----------------------------------------------------------

interface BossRecord {
  bossId: string;
  hpPool: number;
  hpRemaining: number;
  endsAt: number;
  contributors: { [userId: string]: number };
}

/**
 * The shared health pool, and this caller's share of it.
 *
 * One encounter at a time, owned by the server. Each client tracking its own copy of a
 * shared pool would show every member of a guild a different boss.
 */
const rpcBossState: nkruntime.RpcFunction = (ctx, _logger, nk, _payload) => {
  const userId = requireUser(ctx);
  const scope = bossScope(nk, userId);
  const record = bossFor(nk, scope);
  if (record === null) return JSON.stringify({ encounter: null });

  return JSON.stringify({
    encounter: {
      boss: record.bossId,
      pool: record.hpPool,
      remaining: record.hpRemaining,
      ends_at: record.endsAt,
      contributed: record.contributors[userId] || 0,
      contributors: Object.keys(record.contributors).length,
      // Which pool this is. A player in a guild is chipping at their guild's colossus;
      // a player without one has their own, so the mode is not gated behind finding
      // people to play with.
      // A PREFIX test. The solo key is `solo:<userId>`, so comparing it to the prefix
      // itself is never equal and every guildless player was told they were in a guild
      // pool -- the one thing this field exists to tell them apart.
      scope: scope.indexOf(SOLO_SCOPE) === 0 ? "solo" : "guild",
    },
  });
};


/** The pool a player's damage goes into: their guild's, or their own. */
function bossScope(nk: nkruntime.Nakama, userId: string): string {
  const guild = userGuild(nk, userId);
  return guild === null ? SOLO_SCOPE + userId : guild.id;
}


/**
 * A scope's encounter, created from the open template the first time anybody looks.
 * Returns null when no encounter is open at all.
 */
function bossFor(nk: nkruntime.Nakama, scope: string): BossRecord | null {
  const existing = readBoss(nk, scope);
  const template = readBoss(nk, BOSS_TEMPLATE_KEY);
  if (template === null) return existing;

  const now = Math.floor(Date.now() / 1000);
  if (template.endsAt <= now) return existing;
  // A stale instance from a previous window is replaced rather than resumed, or a guild
  // that skipped a week would start the next one on a boss already half dead.
  if (existing !== null && existing.bossId === template.bossId
      && existing.endsAt === template.endsAt) {
    return existing;
  }

  const fresh: BossRecord = {
    bossId: template.bossId,
    hpPool: template.hpPool,
    hpRemaining: template.hpPool,
    endsAt: template.endsAt,
    contributors: {},
  };
  writeBoss(nk, fresh, scope);
  return fresh;
}

/**
 * Opens (or reopens) the encounter. Worker-only: which boss is up, how much health it
 * has and how long the window runs are live-ops decisions, not client ones.
 */
const rpcOpenBoss: nkruntime.RpcFunction = (ctx, logger, nk, payload) => {
  requireWorker(ctx);
  const body = JSON.parse(payload || "{}") as {
    bossId?: string; hpPool?: number; durationHours?: number;
  };
  if (!body.bossId) throw new Error("a boss id is required");

  // A TEMPLATE, not a pool. Each guild gets its own instance of it, created the first
  // time a member looks -- otherwise opening an encounter would mean writing a record
  // for every guild that exists, including the ones nobody plays.
  const template: BossRecord = {
    bossId: body.bossId,
    hpPool: clampInt(body.hpPool, 1, 1000000000),
    hpRemaining: clampInt(body.hpPool, 1, 1000000000),
    endsAt: Math.floor(Date.now() / 1000) + clampInt(body.durationHours, 1, 8760) * 3600,
    contributors: {},
  };
  writeBoss(nk, template, BOSS_TEMPLATE_KEY);
  logger.info("boss %s opened with %d hp", template.bossId, template.hpPool);
  return JSON.stringify({ ok: true, boss: template.bossId, pool: template.hpPool });
};

/**
 * Moves a decided match out of the queue. Written to the archive FIRST: a crash between
 * the two leaves a duplicate record, which is harmless, where the other order would lose
 * the only evidence of a verdict.
 */
function archive(
  nk: nkruntime.Nakama,
  decided: { collection: string; key: string; userId: string },
  pending: { collection: string; key: string; userId: string },
  record: PendingRecord,
): void {
  nk.storageWrite([{
    collection: decided.collection, key: decided.key, userId: decided.userId,
    value: record as unknown as { [key: string]: unknown },
    permissionRead: 0, permissionWrite: 0,
  }]);
  try {
    nk.storageDelete([pending]);
  } catch (_error) {
    // Left in the queue; the next claim re-decides it, which is idempotent.
  }
}


function readBoss(nk: nkruntime.Nakama, key: string): BossRecord | null {
  try {
    const stored = nk.storageRead([{
      collection: BOSS_COLLECTION, key, userId: SYSTEM_USER,
    }]);
    return stored.length > 0 ? (stored[0].value as unknown as BossRecord) : null;
  } catch (_error) {
    return null;
  }
}

function writeBoss(nk: nkruntime.Nakama, record: BossRecord, key: string): void {
  nk.storageWrite([{
    collection: BOSS_COLLECTION, key, userId: SYSTEM_USER,
    value: record as unknown as { [key: string]: unknown },
    // Public to read — everyone in the fight needs to see the same bar. Server-only to
    // write, because the bar IS the reward.
    permissionRead: 2, permissionWrite: 0,
  }]);
}

/**
 * Applies verified damage to the pool. Called from the verdict path only: the number
 * comes from the worker's re-run, never from the client that claimed it.
 */
function applyBossDamage(
  nk: nkruntime.Nakama, logger: nkruntime.Logger, userId: string, damage: number,
): number {
  const scope = bossScope(nk, userId);
  const record = bossFor(nk, scope);
  if (record === null || damage <= 0) return 0;

  const applied = Math.min(damage, record.hpRemaining);
  record.hpRemaining -= applied;
  record.contributors[userId] = (record.contributors[userId] || 0) + applied;
  writeBoss(nk, record, scope);

  logger.info("boss %s: -%d (%d left)", record.bossId, applied, record.hpRemaining);
  return applied;
}

// --- The verification worker -------------------------------------------------

/**
 * Hands the worker a batch of unverified submissions and marks them claimed, so two
 * workers cannot both verify the same match.
 */
const rpcWorkerClaim: nkruntime.RpcFunction = (ctx, logger, nk, payload) => {
  requireWorker(ctx);
  const body = JSON.parse(payload || "{}") as { count?: number };
  const limit = clampInt(body.count, 1, 50);

  // Paged: the scan reads storage objects, not pending ones, so a page full of records
  // that are not live work would otherwise hide everything behind it.
  const claimed = [];
  let cursor = "";
  let pages = 0;
  while (claimed.length < limit && pages < 10) {
    const listed = nk.storageList(undefined, PENDING_COLLECTION, limit * 4, cursor);
    const objects = listed.objects || [];
    if (objects.length === 0) break;
    cursor = String(listed.cursor || "");

  for (const object of objects) {
    const value = object.value as unknown as PendingRecord;
    if (value.state !== "pending") continue;

    value.state = "claimed";
    value.claimedAt = Math.floor(Date.now() / 1000);
    nk.storageWrite([{
      collection: PENDING_COLLECTION, key: object.key!, userId: object.userId!,
      value: value as unknown as { [key: string]: unknown },
      permissionRead: 0, permissionWrite: 0,
    }]);

    // The defender's squad and doctrine are attached from SERVER storage. The worker
    // checks the submitted setup against them, which is what stops a client submitting
    // a real battle it really won -- against an opponent it invented.
    const bossId = contextTarget(value.submission, "boss:");
    const tournamentId = contextTarget(value.submission, "tourney:");
    const defenderId = defenderOf(value.submission);
    // Bots are generated deterministically by the GAME, from a seed. The worker runs the
    // game's code, so it can rebuild any bot exactly; this module cannot, and must not
    // try — a second implementation of bot generation is a second thing to drift.
    const isBot = defenderId.indexOf("bot_") === 0;
    const defence = defenderId && !isBot ? readDefence(nk, defenderId) : null;

    claimed.push({
      matchId: object.key,
      submitter: object.userId,
      submission: value.submission,
      defenderId,
      bossId,
      tournamentId,
      // The challenge is generated from the id AND the start time, so the worker cannot
      // rebuild it without both. Sent from the server's own record, never the client's.
      tournamentStart: tournamentId ? tournamentStartOf(nk, tournamentId) : 0,
      isBot,
      defenderSquad: defence ? defence.squad : null,
      defenderDoctrine: defence ? defence.doctrine : [],
    });
    if (claimed.length >= limit) break;
  }

    pages += 1;
    if (cursor === "") break;
  }

  logger.debug("worker claimed %d submissions", claimed.length);
  return JSON.stringify({ matches: claimed });
};

/**
 * Applies a verdict. **This is the only place a rating ever moves.**
 *
 * The worker re-ran the battle with the real simulation; if it says the client lied,
 * nothing is paid out and the submission is kept as evidence. Note that the rating
 * change is computed HERE from the stored ratings of both players, not taken from the
 * worker and certainly not from the client.
 */
const rpcWorkerVerdict: nkruntime.RpcFunction = (ctx, logger, nk, payload) => {
  requireWorker(ctx);
  const body = JSON.parse(payload || "{}") as {
    matchId?: string; submitter?: string; accepted?: boolean;
    verdict?: string; defenderId?: string; won?: boolean; defenderRating?: number;
    bossId?: string; damage?: number; tournamentId?: string; score?: number;
  };
  if (!body.matchId || !body.submitter) throw new Error("matchId and submitter required");

  const stored = nk.storageRead([{
    collection: PENDING_COLLECTION, key: body.matchId, userId: body.submitter,
  }]);
  if (stored.length === 0) throw new Error("no such submission");
  const record = stored[0].value as unknown as PendingRecord;

  record.state = body.accepted ? "accepted" : "rejected";
  record.verdict = String(body.verdict || "");
  record.decidedAt = Math.floor(Date.now() / 1000);
  const decided = { collection: DECIDED_COLLECTION, key: body.matchId, userId: body.submitter };
  const pending = { collection: PENDING_COLLECTION, key: body.matchId, userId: body.submitter };

  // A colossus attempt is scored on damage, not on winning: the whole design is that a
  // squad which loses the battle still moved the bar.
  if (body.accepted && body.tournamentId) {
    record.score = applyTournamentScore(
      nk, logger, body.tournamentId, body.submitter, clampInt(body.score, 0, 100000000));
    record.state = "accepted";
    archive(nk, decided, pending, record);
    return JSON.stringify({ ok: true, state: record.state, score: record.score });
  }

  if (body.accepted && body.bossId) {
    record.damage = applyBossDamage(nk, logger, body.submitter, clampInt(body.damage, 0, 10000000));
    record.state = "accepted";
    archive(nk, decided, pending, record);
    return JSON.stringify({ ok: true, state: record.state, damage: record.damage });
  }

  let delta = 0;
  if (body.accepted && body.defenderId) {
    const isBot = body.defenderId.indexOf("bot_") === 0;
    const attacker = ownRecord(nk, body.submitter);
    const attackerRating = attacker === null ? BASE_RATING : Number(attacker.score);
    // A bot has no ladder record; its rating comes from the worker, which generated it.
    // Trusting the worker here is fine — it is server-side, and it is the thing that
    // just re-ran the battle.
    const defenderRating = isBot
      ? clampInt(body.defenderRating, 0, 5000)
      : ratingOf(nk, body.defenderId);
    delta = ratingDelta(
      attackerRating, defenderRating, body.won === true,
      attacker === null ? 0 : Number(attacker.numScore) || 0);

    nk.leaderboardRecordWrite(
      RANKED_LEADERBOARD, body.submitter, "", Math.max(0, attackerRating + delta), 0, {});
    if (!isBot) {
      // A real defender moves too, even though they were not present. That is what makes
      // an idle ladder still a ladder. A bot has nowhere to move.
      nk.leaderboardRecordWrite(
        RANKED_LEADERBOARD, body.defenderId, "", Math.max(0, defenderRating - delta), 0, {});
    }
  }
  record.delta = delta;
  archive(nk, decided, pending, record);

  logger.info("match %s %s (%d)", body.matchId, record.state, delta);
  return JSON.stringify({ ok: true, state: record.state, delta });
};

/** The submission's context is `pvp:<defender id>` or `boss:<boss id>`. */
function defenderOf(submission: unknown): string {
  return contextTarget(submission, "pvp:");
}


function tournamentStartOf(nk: nkruntime.Nakama, tournamentId: string): number {
  try {
    const found = nk.tournamentsGetId([tournamentId]);
    return found.length > 0 ? Number(found[0].startTime) || 0 : 0;
  } catch (_error) {
    return 0;
  }
}


function contextTarget(submission: unknown, prefix: string): string {
  const context = String((submission as { context?: string })?.context || "");
  return context.indexOf(prefix) === 0 ? context.slice(prefix.length) : "";
}


function readDefence(nk: nkruntime.Nakama, userId: string): DefenceRecord | null {
  try {
    const stored = nk.storageRead([{
      collection: DEFENCE_COLLECTION, key: "current", userId,
    }]);
    return stored.length > 0 ? (stored[0].value as unknown as DefenceRecord) : null;
  } catch (_error) {
    return null;
  }
}


/**
 * Elo, mirroring `Ranked.rating_delta` on the client.
 *
 * The client computes this too, for a number to show immediately. **This one is the
 * real one** — if they disagree, the client's guess is corrected on the next refresh.
 */
function ratingDelta(
  own: number, opponent: number, won: boolean, matchesPlayed: number,
): number {
  let k = K_STABLE;
  if (matchesPlayed < PLACEMENT_MATCHES) k = K_PLACEMENT;
  else if (matchesPlayed < PLACEMENT_MATCHES * 4) k = K_SETTLING;

  // The client works in integers scaled by 1000 to keep the same arithmetic on every
  // platform; here the rounding is what has to agree, so it is done the same way.
  const expected = Math.round(1000 / (1 + Math.pow(10, (opponent - own) / 400)));
  const delta = Math.trunc((k * ((won ? 1000 : 0) - expected)) / 1000);
  return won ? Math.max(1, delta) : Math.min(-1, delta);
}

/**
 * The worker authenticates with the HTTP key, which Nakama itself has already
 * validated by the time we are called — an http_key request arrives with no user.
 * A signed-in client therefore can never reach these, whatever it sends.
 */
function requireWorker(ctx: nkruntime.Context): void {
  if (ctx.userId) throw new Error("worker endpoints are not client-callable");
}

/** Cloud save. The profile is server-authoritative once accounts exist. */
const rpcSyncProfile: nkruntime.RpcFunction = (ctx, _logger, nk, payload) => {
  const userId = requireUser(ctx);
  const body = JSON.parse(payload || "{}") as { profile?: Record<string, unknown> };

  if (body.profile) {
    nk.storageWrite([{
      collection: PROFILE_COLLECTION, key: "current", userId,
      value: body.profile, permissionRead: 1, permissionWrite: 0,
    }]);
    return JSON.stringify({ ok: true, saved: true });
  }

  const stored = nk.storageRead([{ collection: PROFILE_COLLECTION, key: "current", userId }]);
  return JSON.stringify({ ok: true, profile: stored.length ? stored[0].value : null });
};

// --- Helpers -----------------------------------------------------------------

function requireUser(ctx: nkruntime.Context): string {
  if (!ctx.userId) throw new Error("authentication required");
  return ctx.userId;
}

function clampInt(value: unknown, low: number, high: number): number {
  const n = Math.floor(Number(value) || 0);
  return Math.min(high, Math.max(low, n));
}

function ratingOf(nk: nkruntime.Nakama, userId: string): number {
  const own = ownRecord(nk, userId);
  return own === null ? BASE_RATING : Number(own.score) || BASE_RATING;
}

/**
 * The caller's own ladder record, or null.
 *
 * `leaderboardRecordsList` puts the requested owners in **`ownerRecords`**; `records`
 * is the general ranked page and is populated whether or not the caller is on it.
 * Reading `records` instead returned the top player's row for everybody — so the second
 * account to publish was told it already had a record, and never joined the ladder.
 */
function ownRecord(
  nk: nkruntime.Nakama, userId: string,
): nkruntime.LeaderboardRecord | null {
  try {
    const listed = nk.leaderboardRecordsList(RANKED_LEADERBOARD, [userId], 1);
    if (listed.ownerRecords && listed.ownerRecords.length > 0) {
      return listed.ownerRecords[0];
    }
  } catch (_error) {
    // No record yet, or no leaderboard yet.
  }
  return null;
}

/**
 * Puts a player on the ladder at their current rating, once.
 *
 * Deliberately does NOT overwrite an existing score: this runs on every defence
 * publish, and a player who updates their squad after losing ten matches must not be
 * quietly restored to where they started.
 */
function ensureLadderRecord(
  nk: nkruntime.Nakama, userId: string, username: string, rating: number,
): void {
  try {
    if (ownRecord(nk, userId) !== null) return;
    nk.leaderboardRecordWrite(RANKED_LEADERBOARD, userId, username, rating, 0, {});
  } catch (_error) {
    // A ladder write failing must not stop the defence being stored. The player is
    // simply not matchable until the next publish, which is recoverable; losing their
    // defence is not.
  }
}

/**
 * A crude fixed-window limiter. Enough to stop a script farming the ladder; not enough
 * to stop a determined attacker, which is what the verifier is for.
 */
function rateLimitOk(nk: nkruntime.Nakama, userId: string): boolean {
  const key = RATE_LIMIT_KEY;
  const now = Math.floor(Date.now() / 1000);
  const stored = nk.storageRead([{ collection: RATE_COLLECTION, key, userId }]);

  let windowStart = now;
  let count = 0;
  if (stored.length > 0) {
    const value = stored[0].value as { windowStart?: number; count?: number };
    windowStart = Number(value.windowStart) || now;
    count = Number(value.count) || 0;
    if (now - windowStart >= SUBMIT_WINDOW_SEC) {
      windowStart = now;
      count = 0;
    }
  }

  if (count >= SUBMIT_LIMIT) return false;

  nk.storageWrite([{
    collection: RATE_COLLECTION, key, userId,
    value: { windowStart, count: count + 1 },
    permissionRead: 0, permissionWrite: 0,
  }]);
  return true;
}

// Nakama looks this up by name on the global object.
!InitModule && InitModule.bind(null);
