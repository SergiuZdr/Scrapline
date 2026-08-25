# Scrapline server

Nakama + Postgres, plus a headless Godot verification worker. **Running and verified
end to end** — see "Proof" at the bottom.

## Run it

```bash
brew install colima docker docker-compose   # Colima, not Docker Desktop: no licence, no GUI
colima start --cpu 2 --memory 4 --disk 30   # first run downloads a ~350 MB VM image

cd server/modules && npm install && npm run build
cd .. && docker compose up -d
open http://127.0.0.1:7351      # console, admin/password
```

Then point the game at it:

```bash
godot --path . -- --server 127.0.0.1:7350       # or write user://server.json
godot --headless --path . --script res://tools/verify_online.gd   # the whole loop, asserted
godot --headless --path . --script res://tools/verify_worker.gd -- \
    --nakama http://127.0.0.1:7350 --http-key defaulthttpkey      # add --once for a single pass
```

Nothing here is per-player-priced. Nakama is one Go binary and Postgres is Postgres;
the whole thing fits the plan's ~$12/month VPS budget.

## The verification split — the important part

The battle simulation is GDScript. Nakama's runtime is TypeScript. **Neither can run the
other, and the simulation must never be re-implemented in TypeScript.** Two
implementations of a deterministic simulation drift, and the day they disagree every
honest player starts getting rejected.

So the flow is:

```
client ──submission──▶ Nakama (auth, rate limit, store as "pending")
                          │
                          ▼
              headless Godot verify_worker
              re-runs the REAL simulation
                          │
                          ▼
              verdict ──▶ Nakama applies or revokes rating
```

One implementation of the rules, ever. The worker is the same binary and the same
`sim/` code the player's device runs.

A submission is **orders, not events** — 1,066 bytes for a ~2,500-event battle — so this
costs nothing on a bad connection, and verification runs in roughly 80 ms.

### What Nakama enforces (it can)
- identity, from the session rather than a client field
- the defender's squad and doctrine come from **server storage**, never the attacker's
  payload — otherwise an attacker could hand their opponent a useless doctrine
- rate limits
- rating changes, computed server-side from stored ratings, and **only** on a verdict

### What the worker enforces (only it can)
- the battle actually plays out the way the client claimed
- the opponent in it is the squad that player really published

### What neither covers, stated plainly
- **A bot submitting genuine wins.** Verification proves a battle is real, not that a
  human played it. That is behavioural detection, not verification.
- **A tampered local save.** Cloud-authoritative profile state covers that, which is
  why the roster lives on the server once accounts exist.

## Nakama's sharp edges

Every one of these cost a debugging session. They fail *quietly* — the code runs, the
call succeeds, and the data is wrong.

| Edge | What happens if you get it wrong |
|---|---|
| **RPC payloads are double-encoded.** The body is a JSON *string* containing your JSON, and the reply is an envelope whose `payload` is a JSON string. | The RPC "succeeds" and your handler sees nothing. |
| **`leaderboardRecordsList(id, [owner])` puts that owner in `ownerRecords`.** `records` is the general ranked page and is populated regardless. | Reading `records` returns the *top player's* row for everyone. Ours meant the second account to publish was told it already had a ladder record, so it never joined. |
| **Use `leaderboardRecordsHaystack` for "players near me".** | `leaderboardRecordsList` returns your own record; the opponent list comes back empty forever. |
| **Enum values are not the strings they look like** — `SortOrder.DESCENDING` is `"descending"`, not `"desc"`. | `leaderboardCreate` throws, and since creation is wrapped in try/catch (it is not idempotent), the leaderboard silently never exists. |
| **Usernames are unique server-wide.** | Sending the player's display name at sign-in works for the *first* player and 409s for every one after. The client sends no username; the visible name travels with the defence record. |
| **Device ids must be at least 10 characters.** | Shorter ids return a token that is rejected on first use, which reads like an auth bug. |
| **Leaderboard config is fixed at creation.** `leaderboardCreate` on an existing id throws and changes nothing. | We had `authoritative: false` for a day — clients could have written their own scores. Changing config means a new id or an explicit migration. |
| **`r.PathValue` vs the route pattern.** Nakama 3.24.0's HTTP RPC endpoint never reads the id out of the path; every call fails with "RPC ID must be set". | Fixed in later releases. Pinned to **3.40.0**. |

## Live ops

```bash
# What is running right now, read the way a player sees it
godot --headless --path . --script res://tools/liveops.gd -- --status

# Start things
godot --headless --path . --script res://tools/liveops.gd -- --open-boss
godot --headless --path . --script res://tools/liveops.gd -- --open-tournament --hours 72
```

Nakama's tournaments need an explicit **end time**, not only a duration — `duration` is
the length of a reset cycle, and leaving `endTime` at zero means "never ends", which
reads to a client as zero hours remaining. Its `tournamentList` time arguments are
filters, so passing zeros asks for tournaments ending at the epoch and finds nothing.

```bash
# Ship a balance change to everyone. Dry-runs a battle under it first.
godot --headless --path . --script res://tools/publish_content.gd -- \
    --file patches/example_season_two.json --dry-run
godot --headless --path . --script res://tools/publish_content.gd -- \
    --file patches/example_season_two.json

godot --headless --path . --script res://tools/publish_content.gd -- --show
godot --headless --path . --script res://tools/publish_content.gd -- --clear
```

Players pick a patch up at their next launch; the worker at its next start. **Both
must**: a server shipping new numbers while its verifier runs the old ones rejects every
honest submission at once. The worker prints the content hash it settled on for exactly
this reason.

A patch is only what changes — one part's reach, one balance field, a whole new
Battlefield Condition for the season. Unknown ids are added, known ids are merged field
by field, so a patch never silently reverts a field it forgot to restate.

## The co-op boss

```bash
# Open an encounter (worker-only, like every other live-ops action)
curl -s -X POST "http://127.0.0.1:7350/v2/rpc/open_boss?http_key=defaulthttpkey" \
  -H 'Content-Type: application/json' \
  -d '"{\"bossId\":\"boss_kiln_walker\",\"hpPool\":900000,\"durationHours\":168}"'
```

The pool is server-owned and public to read — everyone in the fight has to see the same
bar. It moves **only** on a verdict, by the damage the worker's own re-run computed. An
attempt is scored on damage rather than on winning, so a squad that loses having taken an
arm off still moved it.

## Purchases

`validate_purchase` is keyed on the store's **order id**, stored under the system user
rather than the buyer — a per-player key would let one receipt be redeemed once on each
of a hundred accounts, which is the whole attack.

`verifyWithStore` is where Google Play's Developer API call goes. It returns **false**
until it is written: an unimplemented validator that accepts everything looks like
protection while accepting forgeries.

Receipts from the development billing stub are honoured only when
`SCRAPLINE_ALLOW_DEV_PURCHASES=true` is passed via **`--runtime.env`** — not a container
environment variable, which `ctx.env` does not read. It is absent from any production
compose file rather than set to false, so forgetting to change it cannot leave it on.

Two things that cost a debugging pass each, both worth knowing before editing the compose
file or the queue:

- the entrypoint is a YAML **folded scalar**, so it becomes a single shell line. A `#`
  comment inside it comments out every flag that follows.
- decided matches are archived out of `pvp_pending`, and rate counters live in their own
  collection. The worker's claim scans a page of *storage*, not a page of *pending*
  records, so anything else left in that collection eventually hides the live work behind
  it — silently, with submissions queueing and nothing reporting an error.

## Try the flow without a server

```bash
godot --headless --path . --script res://tools/make_submissions.gd -- --out user://queue
godot --headless --path . --script res://tools/verify_worker.gd -- --in user://queue --out user://verdicts
```

Writes one honest submission and three forged ones, then drains the queue. Expect
`1 accepted, 3 rejected`.

## Typecheck and build

```bash
cd server/modules && npm run typecheck && npm run build
```

`tsc` only — no bundler. `main.ts` has no imports, so the emitted script keeps
`InitModule` at top level where Nakama looks for it; a bundler's IIFE wrapper would hide
it. `nkruntime.d.ts` is the official definition file vendored from
[heroiclabs/nakama-common](https://github.com/heroiclabs/nakama-common) — it ships with
the server and is **not on npm**, every package name you would guess 404s. It replaced a
hand-written subset that typechecked perfectly and was wrong about half the signatures
above.

## Proof

`tools/verify_online.gd`, run against this stack: 49/49.

- two accounts sign in, publish defences, and find each other
- an honest battle submits, verifies, and moves both ratings (attacker 1000 → 991,
  defender +9 without being present)
- the rating does **not** move before the worker has verified it
- a lied winner is caught (`rejected: winner differs`)
- a battle against a squad the defender never published is caught (`DEFENCE_MISMATCH`)
- an unsupported payload version is refused at submission
- a bot match verifies (the worker rebuilds the bot from its seed) and moves the rating
- an invented bot squad is caught the same way an invented player's is
- a receipt validates once, is a duplicate the second time, and cannot be redeemed by
  another account
- a receipt claiming to be real is refused while store validation is unimplemented
- a guild forms, is findable, and two members chip at ONE colossus pool while a player
  without a guild has their own
- a tournament ranks verified attempts, refuses a score from somebody who never entered,
  and catches an invented challenge squad
- a signed-in client cannot reach the worker endpoints

Plus the real client, driven headlessly end to end:

```bash
godot --headless --path . --quit-after 20000 -- --server 127.0.0.1:7350 --attack 0 --autoplay
godot --headless --path . --script res://tools/verify_worker.gd -- --nakama http://127.0.0.1:7350 --once
```

Ranked screen → ATTACK → battle → submission → verdict → the client adopts the server's
rating on next launch (it had predicted 1072; the ladder said 1026, and 1026 won).
