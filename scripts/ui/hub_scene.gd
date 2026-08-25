extends Control

## The Foundry hub: everything between battles.
##
## Rebuilt around one rule — **the screen's job is to tell the player what to decide
## right now.** The first version was five terse tabs of equal weight with no
## indication of what any of them were for or which one mattered, which is a wall to
## anyone who did not write it.
##
## Three things carry that load:
##
##   - **The Next card.** Permanent, top of screen, always naming the single best
##     action available. A new player never has to work out what to do; they can play
##     the whole campaign off this one button.
##   - **Named navigation with a purpose line.** "Foundry" means nothing on its own.
##     "FOUNDRY — collect what your yard produced" means something immediately.
##   - **Badges.** A dot on a section that has something waiting is how a player learns
##     where to look, without being told.
##
## Help is inline and toggled, never hover. There is no hover on a phone, and this
## ships on phones.

## Every colour here is an alias onto `UIKit`, which is also what the battlefield HUD
## draws from. The names are kept because thirty-nine call sites read better as COL_ROW
## than as UIKit.SURFACE_HIGH -- but there is exactly one palette, and it lives in UIKit.
const COL_BG := UIKit.BG
const COL_PANEL := UIKit.SURFACE
const COL_NAV := UIKit.BG
const COL_NAV_SEL := UIKit.SURFACE_HIGH
const COL_ROW := UIKit.SURFACE
const COL_TEXT := UIKit.TEXT
const COL_DIM := UIKit.TEXT_DIM
const COL_GOLD := UIKit.GOLD
const COL_GOOD := UIKit.GREEN
const COL_ACCENT := UIKit.BLUE
const COL_WARN := UIKit.RED
## The primary action on any screen. See UIKit -- one per screen, or it stops signalling.
const COL_PRIMARY := UIKit.AMBER

## How many rungs of the tower to show. Enough to see the power curve rising, few enough
## that the screen is not a wall of identical rows.
const GAUNTLET_LADDER_ROWS: int = 6

## Rarity colours, used by the crate odds bar and anywhere else rarity is shown. Kept
## here so one rarity never reads as two different colours on two screens.
const RARITY_COLOURS: Dictionary = {
	1: UIKit.TEXT_DIM, 2: UIKit.GREEN, 3: UIKit.BLUE, 4: UIKit.AMBER, 5: UIKit.RED,
}

const NAV: Array = [
	{"id": "campaign", "icon": "▶", "name": "CAMPAIGN", "purpose": "fight for the next foundry",
	 "help": "Nodes are fought in order. Each first clear pays scrap and sometimes a new part; replaying a cleared node pays less. Your squad fights on its own unless you give it orders during the battle."},
	{"id": "foundry", "icon": "⌂", "name": "FOUNDRY", "purpose": "collect what your yard produced",
	 "help": "Buildings produce while the game is closed, up to a storage limit. Come back, collect, and spend it. The Salvage Yard makes scrap, the Smelter makes alloy, and the Reactor refills the charge a sortie costs."},
	{"id": "gauntlet", "icon": "▲", "name": "GAUNTLET", "purpose": "climb as deep as you can",
	 "help": "An endless tower. Floor 1 is easy and every floor after it is harder. Winning moves you up; losing sends you back to floor 1. Your best depth is kept forever, and the run resets each week. It pays better than replaying a cleared campaign node, so this is where to farm when you are stuck."},
	{"id": "colossus", "icon": "◉", "name": "COLOSSUS", "purpose": "everyone fights one thing",
	 "help": "A machine far too big for one squad. Its core is armoured while any limb still stands, so opening on the core wastes the attempt — break the arms first, then the core. You are NOT expected to win: an attempt is scored on damage dealt, and a squad that dies having taken an arm off has done its job. Everyone's damage comes off the same pool, and everyone who landed a hit is paid when it falls."},
	{"id": "ranked", "icon": "◆", "name": "RANKED", "purpose": "fight other Reclaimers",
	 "help": "You fight a SNAPSHOT of another player's squad, run by the doctrine they wrote — nobody has to be online. Winning against someone rated above you is worth far more than beating someone below, so farming the bottom of the ladder gets you nowhere. Your own squad defends against other players while you are away, so keep it and your doctrine current. Every season the Battlefield Condition changes, and the squad that answered last season usually is not the answer to this one."},
	{"id": "tournament", "icon": "◆", "name": "TOURNAMENT", "purpose": "everyone fights one fight",
	 "help": "A scheduled event where every entrant faces the SAME generated squad on the same map under the same Condition — so the table ranks how well you built and commanded, not who drew the kinder opponent. You get a handful of attempts and your best one counts. Losing still scores: damage counts, and winning with constructs still standing counts for much more."},
	{"id": "parts", "icon": "⚙", "name": "PARTS", "purpose": "make your constructs stronger",
	 "help": "Scrap raises a part's LEVEL. Its level ceiling comes from its TIER, and only a REFIT raises the tier — which costs duplicates of that part. So duplicates are not waste; they are the only way past a cap."},
	{"id": "pass", "icon": "◈", "name": "SEASON", "purpose": "a track that pays as you play",
	 "help": "Every battle you fight — campaign, gauntlet, ranked, colossus — earns season XP up to a daily limit, and every tier pays out. The free track runs the whole way; the Foundry Pass adds a second reward at every tier and pays out everything you have ALREADY earned the moment you buy it, so buying late costs you nothing. The season resets on its own clock, and anything left unclaimed when it ends is gone."},
	{"id": "store", "icon": "◇", "name": "STORE", "purpose": "cores, and what they buy",
	 "help": "Cores are the premium currency. They buy alloy, scrap and Reactor charges here, and crates in the Crates screen — crates are never sold for money directly, so the published odds always apply to something you chose to spend. Nothing here is required to finish the campaign or to climb the ladder; it buys time, not power."},
	{"id": "crates", "icon": "▣", "name": "CRATES", "purpose": "find parts you do not own",
	 "help": "Crates are the main source of new parts. Odds are printed on every crate. If you go unlucky for long enough, a guaranteed drop fires — the counter is shown next to the odds."},
	{"id": "doctrine", "icon": "✎", "name": "DOCTRINE", "purpose": "teach your squad how to fight",
	 "help": "Rules are checked top to bottom and the first one that matches wins, so ORDER is the whole thing. A unit set to Auto in battle plays by these rules, and later they will run your defence when other players attack you."},
]

var _current: String = "campaign"
var _content_pane: VBoxContainer
var _nav_buttons: Dictionary = {}
## Held directly rather than looked up by path: Godot auto-names unnamed containers
## (@HBoxContainer@11), so any hardcoded node path into them is guaranteed to break.
var _nav_badges: Dictionary = {}
var _currency_row: HBoxContainer
var _next_card: PanelContainer
var _toast: Label
var _help_visible: bool = false
var _help_panel: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	if Session.has_result:
		_show_result_toast()
		Session.has_result = false
	# Signing in happens in the background, so the hub is usually already drawn by the
	# time it lands. Without this the ranked screen keeps saying "offline" for as long as
	# the player stays on it -- while their defence is already on the server.
	Session.net.connection_changed.connect(_on_connection_changed)
	Session.coop.encounter_changed.connect(_on_encounter_changed)
	Session.tournaments.changed.connect(_on_tournament_changed)
	if Session.pvp.repository is NakamaPvpRepository:
		(Session.pvp.repository as NakamaPvpRepository).published.connect(_on_connection_changed)
	_maybe_first_run()
	_maybe_capture()
	_maybe_attack()


## Dev-only: `--attack <index>` launches a ranked match against the nth opponent and
## `--colossus` launches a boss attempt, so the path from a button to a scored result can
## be driven headlessly. Pair either with `--autoplay`, which the battle scene reads.
func _maybe_attack() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--colossus"):
		_on_attempt_colossus.call_deferred()
		return
	var index: int = args.find("--attack")
	if index < 0 or index + 1 >= args.size():
		return
	var opponents: Array = Session.pvp.find_opponents(5)
	var pick: int = int(args[index + 1])
	if pick < 0 or pick >= opponents.size():
		push_error("no opponent at index %d" % pick)
		return
	# A scene change cannot happen while the tree is still building this one.
	_on_attack.call_deferred(opponents[pick] as PvpRepository.Defence)


func _on_tournament_changed() -> void:
	if _current == "tournament":
		_refresh_all()


func _on_encounter_changed() -> void:
	if _current == "colossus":
		_refresh_all()


func _on_connection_changed(_online: bool) -> void:
	if _current == "ranked":
		_refresh_all()


# --- Layout ------------------------------------------------------------------

func _build() -> void:
	# Before anything is constructed, so every control below inherits the house style
	# rather than Godot's default theme.
	UIKit.apply(self)

	var background := ColorRect.new()
	background.color = COL_BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_build_top_bar())

	_next_card = PanelContainer.new()
	root.add_child(_next_card)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root.add_child(body)

	body.add_child(_build_nav())

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 0)
	body.add_child(right)

	_help_panel = PanelContainer.new()
	_help_panel.visible = false
	right.add_child(_help_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)

	# A right margin so action buttons never sit flush against the screen edge, which
	# on a phone is also where the thumb rest and system gestures live.
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 18)
	scroll.add_child(margin)

	_content_pane = VBoxContainer.new()
	_content_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_pane.add_theme_constant_override("separation", 6)
	margin.add_child(_content_pane)

	_refresh_all()


func _build_top_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _flat(COL_PANEL, 0, 18, 12))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	bar.add_child(row)

	var title := _label("SCRAPLINE", UIKit.SIZE_DISPLAY, COL_TEXT)
	# Letterspacing a wordmark is the cheapest thing that separates a title from a label,
	# and Godot has no tracking setting -- so it is spelled out.
	title.text = "S C R A P L I N E"
	title.add_theme_color_override("font_color", UIKit.AMBER)
	row.add_child(title)

	_currency_row = HBoxContainer.new()
	_currency_row.add_theme_constant_override("separation", 22)
	_currency_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_currency_row)

	_toast = _label("", 15, COL_GOOD)
	row.add_child(_toast)

	var help := Button.new()
	help.text = "?  WHAT IS THIS"
	help.custom_minimum_size = Vector2(160, 34)
	help.pressed.connect(_on_toggle_help)
	row.add_child(help)

	return bar


## Currencies with their purpose attached. A bare number teaches nothing; "scrap —
## levels parts" tells a new player what it is for the moment they look at it.
func _refresh_currencies() -> void:
	for child: Node in _currency_row.get_children():
		child.queue_free()

	var p: PlayerProfile = Session.profile()
	var entries: Array = [
		["⬢", p.currency(PlayerProfile.SCRAP), "scrap", "levels parts", COL_GOLD],
		["◆", p.currency(PlayerProfile.ALLOY), "alloy", "refits parts", COL_ACCENT],
		["✦", p.currency(PlayerProfile.CORES), "cores", "premium", COL_GOOD],
	]
	for entry: Variant in entries:
		var e: Array = entry as Array
		_currency_row.add_child(_currency_chip(
			String(e[0]), "%d" % int(e[1]), String(e[2]), String(e[3]), e[4] as Color))

	var progress: Dictionary = Campaign.progress(p, Session.content)
	_currency_row.add_child(_currency_chip("▤",
		"%d / %d" % [int(progress["cleared"]), int(progress["total"])],
		"nodes", "campaign", COL_TEXT))


## A currency as a chip rather than as loose text.
##
## The glyph is tinted and the amount is the largest thing in the chip, because the amount
## is what the player is checking. The purpose line stays -- a bare number teaches a new
## player nothing, and "scrap / levels parts" teaches them the whole economy in two words.
func _currency_chip(glyph: String, amount: String, unit: String, purpose: String,
		tint: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel",
		UIKit.inset(UIKit.SURFACE_SUNK, UIKit.RADIUS_CONTROL, UIKit.SPACE_MD, UIKit.SPACE_SM))

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", UIKit.SPACE_SM)
	chip.add_child(line)

	var mark := _label(glyph, UIKit.SIZE_TITLE, tint)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(mark)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	line.add_child(text)

	var value := HBoxContainer.new()
	value.add_theme_constant_override("separation", UIKit.SPACE_XS)
	text.add_child(value)
	value.add_child(_label(amount, UIKit.SIZE_TITLE, COL_TEXT))
	var unit_label := _label(unit, UIKit.SIZE_LABEL, tint)
	unit_label.size_flags_vertical = Control.SIZE_SHRINK_END
	value.add_child(unit_label)

	text.add_child(_label(purpose, UIKit.SIZE_MICRO, COL_DIM))
	return chip


func _build_nav() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(310, 0)
	panel.add_theme_stylebox_override("panel", _flat(COL_NAV, 0, 8, 10))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)

	for entry: Variant in NAV:
		var e: Dictionary = entry as Dictionary
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 60)
		button.toggle_mode = true
		button.text = ""
		button.pressed.connect(_on_nav.bind(String(e["id"])))
		# Unselected nav items are TRANSPARENT, not cards. Styling all eleven as raised
		# panels made the list read as eleven equally important buttons and the selected
		# one was almost invisible among them -- the amber bar below is the whole point,
		# and it only reads if everything around it is quiet.
		button.add_theme_stylebox_override("normal",
			UIKit.plain(Color(0, 0, 0, 0), UIKit.RADIUS_CONTROL, 12, 8))
		button.add_theme_stylebox_override("hover",
			UIKit.plain(UIKit.SURFACE, UIKit.RADIUS_CONTROL, 12, 8))
		button.add_theme_stylebox_override("pressed", _nav_selected())

		# The label sits inside the button rather than as its text so the name and its
		# purpose line can be styled differently.
		var inner := HBoxContainer.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_theme_constant_override("separation", 10)
		inner.offset_left = 12
		inner.offset_right = -12
		button.add_child(inner)

		inner.add_child(_label(String(e["icon"]), 20, COL_ACCENT))

		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(text)
		text.add_child(_label(String(e["name"]), 16, COL_TEXT))
		text.add_child(_label(String(e["purpose"]), 12, COL_DIM))

		var badge := _label("", 18, COL_GOLD)
		inner.add_child(badge)

		column.add_child(button)
		_nav_buttons[String(e["id"])] = button
		_nav_badges[String(e["id"])] = badge

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	column.add_child(_label("  parts are blueprints —\n  one part can equip\n  several constructs.", 11, COL_DIM))

	return panel


## A dot on a section that has something waiting. This is how a player discovers the
## Foundry has filled up or that they can finally afford an upgrade, without a popup.
func _refresh_badges() -> void:
	var p: PlayerProfile = Session.profile()
	var flags: Dictionary = {
		"foundry": not Foundry.pending(p, Session.content, Session.now()).is_empty(),
		"parts": _any_part_affordable(),
		"crates": _any_crate_affordable(),
		"campaign": false,
		"doctrine": false,
		"gauntlet": false,
		"ranked": false,
		"colossus": false,
		"tournament": false,
		"pass": false,
		"store": false,
	}
	for id: Variant in _nav_badges.keys():
		(_nav_badges[id] as Label).text = "●" if bool(flags.get(id, false)) else ""


func _any_part_affordable() -> bool:
	var p: PlayerProfile = Session.profile()
	for part_id: String in p.owned_part_ids():
		if not p.is_max_level(part_id) \
				and p.can_afford(PlayerProfile.SCRAP, Economy.level_cost(p, part_id, Session.content)):
			return true
	return false


func _any_crate_affordable() -> bool:
	for crate_id: Variant in Session.content.crates.keys():
		if Session.store.can_execute(
				ProfileCommands.OpenCrate.new(String(crate_id))) == ProfileCommand.Result.OK:
			return true
	return false


# --- The Next card -----------------------------------------------------------

## The single most useful element on the screen: what to do, why, and a button that
## does it. A player who reads nothing else can still play the game from this card.
func _refresh_next_card() -> void:
	for child: Node in _next_card.get_children():
		child.queue_free()
	_next_card.add_theme_stylebox_override("panel", _flat(Color("18222e"), 0, 18, 12))

	var p: PlayerProfile = Session.profile()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_next_card.add_child(row)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)

	var pending: Dictionary = Foundry.pending(p, Session.content, Session.now())
	var next: Dictionary = Campaign.next_node(p, Session.content)

	# Collecting first is always right when there is something waiting -- it is free,
	# instant, and it may pay for the upgrade that wins the next fight.
	if not pending.is_empty():
		var bits: PackedStringArray = []
		var keys: Array = pending.keys()
		keys.sort()
		for key: Variant in keys:
			bits.append("%d %s" % [int(pending[key]), String(key)])
		text.add_child(_label("NEXT  ·  collect from your yard", 12, COL_ACCENT))
		text.add_child(_label(" ".join(bits) + " is waiting", 20, COL_TEXT))
		text.add_child(_label("Your buildings produced this while you were away.", 12, COL_DIM))
		row.add_child(_big_button("COLLECT", _on_collect))
		return

	if next.is_empty():
		text.add_child(_label("CAMPAIGN COMPLETE", 12, COL_GOOD))
		text.add_child(_label("Every node cleared.", 20, COL_TEXT))
		text.add_child(_label("Replay any node for scrap while the next zone is built.", 12, COL_DIM))
		return

	var enemies: int = (next["enemy"] as Array).size()
	var reward: Dictionary = next.get("reward", {})
	var detail: String = "%s  ·  %d enemies  ·  +%d scrap" % [
		String(next["zone_name"]), enemies, int(reward.get("scrap", 0))]
	var part_reward: Variant = next.get("first_clear_part", "")
	if part_reward != null and not String(part_reward).is_empty():
		detail += "  ·  new part"

	text.add_child(_label("NEXT  ·  campaign", 12, COL_ACCENT))
	text.add_child(_label("Fight %s" % String(next["name"]), 20, COL_TEXT))
	text.add_child(_label(detail, 12, COL_DIM))
	row.add_child(_big_button("FIGHT", _on_fight.bind(String(next["id"]))))


## The primary action on a screen: COLLECT, FIGHT, CLIMB.
##
## Amber on dark ink, and the only saturated block on the screen. Previously these were
## styled identically to REPLAY and every other secondary control, so a hub full of
## buttons offered no clue which one moved the player forward -- the thing a hub exists
## to answer.
func _big_button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190, 52)
	button.add_theme_font_size_override("font_size", UIKit.SIZE_HEADING)
	button.add_theme_stylebox_override("normal", UIKit.primary())
	button.add_theme_stylebox_override("hover", UIKit.primary(UIKit.AMBER.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", UIKit.primary(UIKit.AMBER_DEEP))
	button.add_theme_stylebox_override("disabled",
		UIKit.plain(UIKit.SURFACE_HIGH, UIKit.RADIUS_CONTROL, UIKit.SPACE_LG, UIKit.SPACE_MD))
	# Dark ink on amber. White on amber fails contrast at this size and reads as a
	# disabled control.
	button.add_theme_color_override("font_color", Color("1a1206"))
	button.add_theme_color_override("font_hover_color", Color("1a1206"))
	button.add_theme_color_override("font_pressed_color", Color("241a08"))
	button.add_theme_color_override("font_disabled_color", UIKit.TEXT_FAINT)
	button.pressed.connect(handler)
	return button


# --- Sections ----------------------------------------------------------------

func _on_nav(id: String) -> void:
	Audio.play("ui_confirm", -18.0)
	if id == "foundry":
		Analytics.milestone("foundry_opened")
	_current = id
	_refresh_all()
	_maybe_show_section_tip(id)


func _on_toggle_help() -> void:
	_help_visible = not _help_visible
	_refresh_help()


func _refresh_help() -> void:
	for child: Node in _help_panel.get_children():
		child.queue_free()
	_help_panel.visible = _help_visible
	if not _help_visible:
		return
	_help_panel.add_theme_stylebox_override("panel", _flat(Color("1d2836"), 0, 18, 12))
	for entry: Variant in NAV:
		var e: Dictionary = entry as Dictionary
		if String(e["id"]) != _current:
			continue
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		_help_panel.add_child(box)
		box.add_child(_label("%s %s" % [String(e["icon"]), String(e["name"])], 15, COL_ACCENT))
		var body := _label(String(e["help"]), 13, COL_TEXT)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(900, 0)
		box.add_child(body)


func _refresh_all() -> void:
	_refresh_currencies()
	_refresh_next_card()
	_refresh_badges()
	_refresh_help()

	for id: Variant in _nav_buttons.keys():
		(_nav_buttons[id] as Button).button_pressed = String(id) == _current

	for child: Node in _content_pane.get_children():
		child.queue_free()

	match _current:
		"campaign": _fill_campaign()
		"foundry": _fill_foundry()
		"gauntlet": _fill_gauntlet()
		"ranked": _fill_ranked()
		"colossus": _fill_colossus()
		"tournament": _fill_tournament()
		"pass": _fill_pass()
		"store": _fill_store()
		"parts": _fill_parts()
		"crates": _fill_crates()
		"doctrine": _fill_doctrine()


func _section_header(title: String, subtitle: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.add_child(_label("  " + title, 19, COL_TEXT))
	box.add_child(_label("  " + subtitle, 12, COL_DIM))
	return box


# --- Campaign ----------------------------------------------------------------

func _fill_campaign() -> void:
	var p: PlayerProfile = Session.profile()
	_content_pane.add_child(_section_header(
		"Campaign", "Cleared nodes can be replayed for reduced scrap. New nodes unlock in order."))

	var zone: int = -1
	for definition: Variant in Campaign.ordered_nodes(Session.content):
		var d: Dictionary = definition as Dictionary
		var id: String = String(d["id"])
		var unlocked: bool = Campaign.is_unlocked(p, Session.content, id)
		var cleared: bool = p.has_cleared(id)

		if not unlocked and not cleared:
			var locked := PanelContainer.new()
			locked.add_theme_stylebox_override("panel", _flat(Color("12161d"), 5))
			var line := HBoxContainer.new()
			locked.add_child(line)
			line.add_child(_label("locked — clear the node above to open the rest of the yard", 13, COL_DIM))
			_content_pane.add_child(locked)
			break

		if int(d["zone"]) != zone:
			zone = int(d["zone"])
			_content_pane.add_child(_label("  " + String(d["zone_name"]).to_upper(), 15, COL_ACCENT))

		_content_pane.add_child(_campaign_row(d, cleared))

	_content_pane.add_child(_squad_panel())


## The squad the player will actually take into the next node, shown under the campaign
## list.
##
## Two jobs. It fills the dead space the node list left below itself -- a screen that
## stops halfway down reads as unfinished no matter how good the top half is. More
## usefully, it answers the question the campaign screen provokes and never addressed:
## "am I strong enough for this one?" The squad was previously invisible from here, so
## checking it meant leaving for the Parts screen and coming back.
func _squad_panel() -> PanelContainer:
	var profile: PlayerProfile = Session.profile()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.card())

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIKit.SPACE_SM)
	panel.add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.SPACE_MD)
	column.add_child(head)
	var title := _label("YOUR SQUAD", UIKit.SIZE_MICRO, COL_DIM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_label("power %d" % Economy.squad_power(profile, Session.content),
		UIKit.SIZE_LABEL, COL_GOLD))

	var squad: Array = profile.squad("main")
	if squad.is_empty():
		column.add_child(_label("no squad built yet — open PARTS", UIKit.SIZE_BODY, COL_WARN))
		return panel

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_SM)
	column.add_child(row)
	for index: int in squad.size():
		row.add_child(_squad_chip(squad[index] as Dictionary))

	if not profile.squad_is_valid("main"):
		# A squad can go invalid when a Refit consumes a part, and the campaign screen is
		# where the player finds out -- by being refused at the FIGHT button, previously
		# with no clue why.
		column.add_child(_label(
			"a part in this squad is no longer owned — fix it in PARTS",
			UIKit.SIZE_LABEL, COL_WARN))
	return panel


## One construct: its chassis picture, its name, and what it is carrying.
func _squad_chip(spec: Dictionary) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_stylebox_override("panel",
		UIKit.inset(UIKit.SURFACE_HIGH, UIKit.RADIUS_CONTROL, UIKit.SPACE_SM, UIKit.SPACE_SM))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	chip.add_child(box)

	var parts: Dictionary = spec.get("parts", {}) as Dictionary
	var chassis_id: String = String(parts.get("chassis", ""))
	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(0, 58)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path: String = "res://art/thumbs/%s.png" % chassis_id
	if ResourceLoader.exists(path):
		picture.texture = load(path)
	box.add_child(picture)

	var chassis: Dictionary = Session.content.parts.get(chassis_id, {})
	box.add_child(_label(String(chassis.get("name", "—")), UIKit.SIZE_MICRO, COL_TEXT))
	var arm: Dictionary = Session.content.parts.get(String(parts.get("arm_r", "")), {})
	box.add_child(_label(String(arm.get("name", "unarmed")), UIKit.SIZE_MICRO, COL_DIM))
	return chip


## A row of chassis pictures for a squad. Used wherever a squad has to be recognised
## rather than counted -- the ranked ladder, and anywhere else an opponent is described.
func _thumb_strip(squad: Array, size: int) -> HBoxContainer:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 2)
	for entry: Variant in squad:
		var spec: Dictionary = entry as Dictionary
		var parts: Dictionary = spec.get("parts", {}) as Dictionary
		var path: String = "res://art/thumbs/%s.png" % String(parts.get("chassis", ""))
		if not ResourceLoader.exists(path):
			continue
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel",
			UIKit.plain(UIKit.SURFACE_HIGH.lightened(0.10), 4, 1, 1))
		var picture := TextureRect.new()
		picture.texture = load(path)
		picture.custom_minimum_size = Vector2(size, size)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.add_child(picture)
		strip.add_child(frame)
	return strip


func _campaign_row(d: Dictionary, cleared: bool) -> PanelContainer:
	var row := PanelContainer.new()
	# A cleared node is history and recedes; the one node the player can actually take is
	# raised and edged in amber. Rendering all thirty identically turned the campaign into
	# a spreadsheet the player had to read top to bottom to find their place in.
	if cleared:
		row.add_theme_stylebox_override("panel", UIKit.plain(UIKit.SURFACE.darkened(0.35),
			UIKit.RADIUS_CONTROL, UIKit.SPACE_MD, UIKit.SPACE_SM))
	else:
		var live := UIKit.card(UIKit.SURFACE_HIGH, UIKit.RADIUS_CONTROL,
			UIKit.SPACE_MD, UIKit.SPACE_MD)
		live.border_color = UIKit.AMBER_DEEP
		row.add_theme_stylebox_override("panel", live)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	row.add_child(line)

	line.add_child(_label("✓" if cleared else ("★" if bool(d.get("is_boss", false)) else "•"),
		16, COL_GOOD if cleared else COL_GOLD))

	var name := _label(String(d["name"]), 15, COL_TEXT)
	name.custom_minimum_size = Vector2(180, 0)
	line.add_child(name)

	var detail: String = "%d enemies" % (d["enemy"] as Array).size()
	var condition_id: String = String(d.get("condition", ""))
	if not condition_id.is_empty():
		detail += "   ·   %s" % String(
			(Session.content.conditions.get(condition_id, {}) as Dictionary).get("name", condition_id))
	detail += "   ·   +%d scrap" % int((d.get("reward", {}) as Dictionary).get("scrap", 0))
	var part_reward: Variant = d.get("first_clear_part", "")
	if part_reward != null and not String(part_reward).is_empty() and not cleared:
		detail += "   ·   + %s" % String(
			(Session.content.parts.get(String(part_reward), {}) as Dictionary).get("name", part_reward))
	var detail_label := _label(detail, 12, COL_DIM)
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(detail_label)

	var fight: Button
	if cleared:
		fight = Button.new()
		fight.text = "REPLAY"
		fight.pressed.connect(_on_fight.bind(String(d["id"])))
	else:
		fight = _big_button("FIGHT", _on_fight.bind(String(d["id"])))
	fight.custom_minimum_size = Vector2(120, 36)
	line.add_child(fight)
	return row


func _on_fight(node_id: String) -> void:
	var p: PlayerProfile = Session.profile()
	if p.squad("main").is_empty():
		_flash("build a squad first", COL_WARN)
		return
	if not p.squad_is_valid("main"):
		_flash("your squad uses parts you no longer own", COL_WARN)
		return
	Session.pending_node_id = node_id
	Session.pending_squad = "main"
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")


# --- Foundry -----------------------------------------------------------------

func _fill_foundry() -> void:
	var p: PlayerProfile = Session.profile()
	var now: int = Session.now()
	_content_pane.add_child(_section_header(
		"Foundry", "Buildings produce while the game is closed, up to their storage limit."))

	for building_id: Variant in Foundry.sorted_ids(Session.content):
		_content_pane.add_child(_building_row(String(building_id), now, p))


func _building_row(building_id: String, now: int, p: PlayerProfile) -> PanelContainer:
	var definition: Dictionary = Session.content.buildings[building_id]
	var level: int = Foundry.level(p, building_id)
	var unlocked: bool = bool(definition.get("unlocked", true))

	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _flat(COL_ROW, 5))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	row.add_child(line)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)

	var heading: String = String(definition["name"])
	heading += ("  ·  not built" if level == 0 else "  ·  level %d" % level)
	text.add_child(_label(heading, 15, COL_TEXT if unlocked else COL_DIM))

	var produces: String = String(definition.get("produces", ""))
	if not produces.is_empty() and level > 0:
		var fill: int = Foundry.fill_percent(p, building_id, Session.content, now)
		text.add_child(_label("%d %s per hour   ·   holds %d hours" % [
			Foundry.rate_per_hour(p, building_id, Session.content), produces,
			int(definition.get("storage_hours", 0))], 12, COL_DIM))
		# A bar, because a full building is WASTING production and that has to be
		# noticeable at a glance rather than parsed out of a percentage in a sentence.
		var fill_bar := ProgressBar.new()
		fill_bar.max_value = 100
		fill_bar.value = fill
		fill_bar.show_percentage = false
		fill_bar.custom_minimum_size = Vector2(0, 6)
		fill_bar.add_theme_stylebox_override("background", UIKit.plain(UIKit.SURFACE_SUNK, 3))
		fill_bar.add_theme_stylebox_override("fill",
			UIKit.plain(COL_WARN if fill >= 100 else (COL_GOLD if fill > 80 else COL_ACCENT), 3))
		text.add_child(fill_bar)
		text.add_child(_label(
			"%d%% full — collect it" % fill if fill > 80 else "%d%% full" % fill,
			UIKit.SIZE_MICRO, COL_GOLD if fill > 80 else COL_DIM))
	else:
		text.add_child(_label(String(definition.get("text", "")), 12, COL_DIM))

	var upgrade := Button.new()
	upgrade.custom_minimum_size = Vector2(230, 36)
	if not unlocked:
		upgrade.text = "LOCKED"
		upgrade.disabled = true
	elif Foundry.at_max_level(p, building_id, Session.content):
		upgrade.text = "MAX LEVEL"
		upgrade.disabled = true
	else:
		var cost: int = Foundry.upgrade_cost(p, building_id, Session.content)
		var currency: String = Foundry.upgrade_currency(building_id, Session.content)
		upgrade.text = "%s   %d %s" % ["BUILD" if level == 0 else "UPGRADE", cost, currency]
		upgrade.disabled = not p.can_afford(currency, cost)
		upgrade.pressed.connect(_on_upgrade_building.bind(building_id))
	line.add_child(upgrade)
	return row


func _on_collect() -> void:
	_after(Session.store.execute(ProfileCommands.CollectFoundry.new(Session.now())), "collected")


func _on_upgrade_building(building_id: String) -> void:
	_after(Session.store.execute(ProfileCommands.UpgradeBuilding.new(building_id)), "built")


# --- Tournament --------------------------------------------------------------

func _fill_tournament() -> void:
	var service: TournamentService = Session.tournaments
	_content_pane.add_child(_section_header(
		"Tournament", "Everyone fights the same fight. Your best attempt is the one that counts."))

	if not service.is_online():
		# There is nothing coherent to show for a ranking against other people while
		# offline, so it says so rather than inventing a local table.
		_content_pane.add_child(_label(
			"  a tournament is a ranking against other players — you are offline", 14, COL_DIM))
		return
	if not service.is_running(Session.now()):
		_content_pane.add_child(_label("  no tournament is running right now", 14, COL_DIM))
		return

	var tournament: Dictionary = service.tournament
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", _flat(Color("18222e"), 5, 16, 14))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	head.add_child(box)
	box.add_child(_label(String(tournament.get("title", "Proving Ground")).to_upper(), 24, COL_GOLD))
	box.add_child(_label(String(tournament.get("description", "")), 13, COL_DIM))

	var left: int = maxi(0, service.ends_at() - Session.now())
	var placing: String = "unranked"
	if service.has_entered():
		placing = "%s points   ·   rank %d" % [
			_big(TournamentService.number(service.own, "score")),
			TournamentService.number(service.own, "rank")]
	box.add_child(_label("%s   ·   %d of %d attempts left   ·   %dh %dm remaining" % [
		placing, service.attempts_left(), service.max_attempts(),
		left / 3600, (left % 3600) / 60], 13, COL_DIM))
	_content_pane.add_child(head)

	var action := Button.new()
	if not service.has_entered():
		action.text = "ENTER"
		action.pressed.connect(_on_enter_tournament)
	else:
		action.text = "FIGHT" if service.attempts_left() > 0 else "NO ATTEMPTS LEFT"
		action.disabled = service.attempts_left() <= 0
		action.pressed.connect(_on_fight_tournament)
	action.custom_minimum_size = Vector2(0, 44)
	_content_pane.add_child(action)

	_content_pane.add_child(_label("  STANDINGS", 15, COL_ACCENT))
	if service.top.is_empty():
		_content_pane.add_child(_label("  nobody has posted a score yet", 13, COL_DIM))
	for entry: Variant in service.top:
		var d: Dictionary = entry as Dictionary
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _flat(COL_ROW, 4))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		row.add_child(line)
		var rank: int = TournamentService.number(d, "rank")
		line.add_child(_label("%d." % rank, 13, COL_GOLD if rank <= 3 else COL_DIM))
		var name_label: Label = _label(String(d.get("name", "")), 14, COL_TEXT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		line.add_child(_label(_big(TournamentService.number(d, "score")), 13, COL_GOLD))
		_content_pane.add_child(row)


func _on_enter_tournament() -> void:
	Session.tournaments.enter(func(ok: bool, message: String) -> void:
		_flash("entered" if ok else message, COL_GOOD if ok else COL_WARN)
		_refresh_all())


func _on_fight_tournament() -> void:
	var p: PlayerProfile = Session.profile()
	if p.squad("main").is_empty() or not p.squad_is_valid("main"):
		_flash("your squad is not ready", COL_WARN)
		return
	Analytics.milestone("tournament_attempt")
	Session.pending_tournament = true
	Session.pending_boss = false
	Session.pending_defence = null
	Session.pending_node_id = ""
	Session.pending_floor = 0
	Session.pending_squad = "main"
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")


# --- Season pass -------------------------------------------------------------

func _fill_pass() -> void:
	var service: PassService = Session.pass_service
	var definition: Dictionary = BattlePass.definition(Session.content)
	var progress: Dictionary = service.progress()
	var tier: int = int(progress["tier"])

	_content_pane.add_child(_section_header(
		String(definition.get("name", "Season")),
		"Every battle counts toward it — campaign, gauntlet, ranked, colossus."))

	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", _flat(Color("18222e"), 5, 16, 14))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	head.add_child(box)
	box.add_child(_label("TIER %d" % tier, 24, COL_GOLD))

	var bar := ProgressBar.new()
	bar.max_value = maxi(1, int(progress["needed"]))
	bar.value = int(progress["into"])
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.add_theme_stylebox_override("background", _flat(Color("0d1014"), 3))
	bar.add_theme_stylebox_override("fill", _flat(COL_GOLD, 3))
	box.add_child(bar)

	var hours: int = BattlePass.seconds_remaining(Session.now(), Session.content) / 3600
	var cap: int = int(definition.get("xp_daily_cap", 0))
	var today: int = service.earned_today(Session.now())
	box.add_child(_label("%d / %d xp to the next tier   ·   %d days %d hours left in the season" % [
		int(progress["into"]), int(progress["needed"]), hours / 24, hours % 24], 13, COL_DIM))
	# The cap is stated whether or not it has been hit. A player who quietly stops
	# earning has no way to tell that from a bug.
	box.add_child(_label("today: %d of %d xp   ·   %s" % [today, cap,
		"the daily limit is reached — tomorrow it resets" if today >= cap
		else "about %d more battles today" % maxi(0, (cap - today) / maxi(1,
			int(definition.get("xp_per_battle", 1)) + int(definition.get("xp_per_win", 0))))],
		12, COL_WARN if today >= cap else COL_DIM))
	_content_pane.add_child(head)

	if not service.premium_unlocked():
		var offer := PanelContainer.new()
		offer.add_theme_stylebox_override("panel", _flat(COL_ROW, 5))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		offer.add_child(line)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 1)
		line.add_child(text)
		text.add_child(_label("Foundry Pass", 15, COL_TEXT))
		text.add_child(_label(
			"a second reward at every tier"
			+ ("" if tier <= 0 else " — including the %d you have already earned" % tier),
			12, COL_DIM))
		var buy := Button.new()
		buy.text = "UNLOCK"
		buy.custom_minimum_size = Vector2(160, 36)
		buy.pressed.connect(_on_buy.bind(String(definition.get("premium_product", "pass_premium"))))
		line.add_child(buy)
		_content_pane.add_child(offer)

	var owed: Array = service.unclaimed()
	if not owed.is_empty():
		var claim := Button.new()
		claim.text = "CLAIM %d REWARD%s" % [owed.size(), "" if owed.size() == 1 else "S"]
		claim.custom_minimum_size = Vector2(0, 42)
		claim.pressed.connect(_on_claim_pass)
		_content_pane.add_child(claim)

	_content_pane.add_child(_label("  THE TRACK", 15, COL_ACCENT))
	# Lane headings. The two rewards on every row were rendered as bare text side by
	# side, so nothing said which one was free and which one needed the pass -- the whole
	# proposition of a two-lane track, unlabelled.
	var lanes := HBoxContainer.new()
	lanes.add_theme_constant_override("separation", UIKit.SPACE_LG)
	var spacer := _label("  ", UIKit.SIZE_MICRO, COL_DIM)
	spacer.custom_minimum_size = Vector2(46, 0)
	lanes.add_child(spacer)
	var free_head := _label("FREE", UIKit.SIZE_MICRO, COL_DIM)
	free_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lanes.add_child(free_head)
	var paid_head := _label(
		"FOUNDRY PASS" if service.premium_unlocked() else "FOUNDRY PASS — LOCKED",
		UIKit.SIZE_MICRO, COL_GOLD if service.premium_unlocked() else COL_DIM)
	paid_head.custom_minimum_size = Vector2(260, 0)
	lanes.add_child(paid_head)
	_content_pane.add_child(lanes)
	# A window around where the player is: the whole 50 rows is a wall, and the tiers
	# that matter are the ones just behind and just ahead.
	var first: int = maxi(1, tier - 2)
	for entry: Variant in BattlePass.tiers(Session.content):
		var d: Dictionary = entry as Dictionary
		var number: int = int(d.get("tier", 0))
		if number < first or number > first + 7:
			continue
		_content_pane.add_child(_pass_tier_row(d, number <= tier, service))


func _pass_tier_row(d: Dictionary, reached: bool, service: PassService) -> PanelContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _flat(COL_ROW if reached else Color("13171f"), 4))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	row.add_child(line)

	var number: int = int(d.get("tier", 0))
	var tier_label := _label("%2d" % number, 15, COL_GOLD if reached else COL_DIM)
	tier_label.custom_minimum_size = Vector2(30, 0)
	line.add_child(tier_label)

	# Each lane is its own cell, so the track reads as two columns rather than as a
	# sentence. A reached tier is lit; an unreached one recedes.
	var free_cell := PanelContainer.new()
	free_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	free_cell.add_theme_stylebox_override("panel", UIKit.plain(
		UIKit.SURFACE_HIGH if reached else UIKit.SURFACE_SUNK, 5, UIKit.SPACE_SM, 4))
	free_cell.add_child(_label(_reward_text(d.get("free", {})), 13,
		COL_TEXT if reached else COL_DIM))
	line.add_child(free_cell)

	var unlocked: bool = service.premium_unlocked()
	var paid_cell := PanelContainer.new()
	paid_cell.custom_minimum_size = Vector2(260, 0)
	var paid_style: StyleBoxFlat = UIKit.plain(
		UIKit.SURFACE_HIGH if (reached and unlocked) else UIKit.SURFACE_SUNK, 5,
		UIKit.SPACE_SM, 4)
	if reached and unlocked:
		paid_style.border_width_left = 2
		paid_style.border_color = UIKit.GOLD
	paid_cell.add_theme_stylebox_override("panel", paid_style)
	paid_cell.add_child(_label(_reward_text(d.get("premium", {})), 13,
		COL_GOLD if (unlocked and reached) else COL_DIM))
	line.add_child(paid_cell)
	return row


## Renders a grant or reward for a player. Handles both part shapes: `parts` is a count
## of random draws (battle pass), `part_ids` is a named list (store bundles).
func _reward_text(reward: Dictionary) -> String:
	var parts: PackedStringArray = []
	var keys: Array = reward.keys()
	keys.sort()
	for key: Variant in keys:
		var name: String = String(key)
		var value: Variant = reward[key]
		if name == "part_ids" and value is Array:
			for id: Variant in (value as Array):
				var part: Dictionary = Session.content.parts.get(String(id), {})
				parts.append(String(part.get("name", String(id))))
		elif name == "parts":
			parts.append("%d part%s" % [int(value), "" if int(value) == 1 else "s"])
		elif name == "pass_premium":
			parts.append("unlocks the season's paid track")
		elif int(value) > 0:
			parts.append("%d %s" % [int(value), name])
	return "  ·  ".join(parts)


func _on_claim_pass() -> void:
	var payout: Dictionary = Session.pass_service.claim_all(Session.now())
	if int(payout.get("claimed", 0)) <= 0:
		_flash("nothing to claim", COL_DIM)
		return
	Session.store.save()
	Audio.play("ui_confirm", -10.0)
	_flash("claimed %d tiers   ·   %s" % [
		int(payout["claimed"]), _reward_text({
			"scrap": int(payout.get("scrap", 0)), "alloy": int(payout.get("alloy", 0)),
			"cores": int(payout.get("cores", 0)), "parts": int(payout.get("parts", 0)),
		})], COL_GOOD)
	_refresh_all()


# --- Store -------------------------------------------------------------------

func _fill_store() -> void:
	var service: StoreService = Session.store_service
	_content_pane.add_child(_section_header(
		"Store", "Cores buy time, not power. Nothing here is needed to finish anything."))

	if not service.billing.is_real():
		# Said plainly, because a stub that looks like real billing in a screenshot is how
		# a build ships unable to take money with nobody noticing.
		var warning := PanelContainer.new()
		warning.add_theme_stylebox_override("panel", _flat(Color("2a1d16"), 5))
		var warning_box := VBoxContainer.new()
		warning_box.add_theme_constant_override("separation", 2)
		warning.add_child(warning_box)
		warning_box.add_child(_label("DEVELOPMENT BUILD — NO PAYMENTS", 14, COL_WARN))
		warning_box.add_child(_label(
			"There is no payment processor attached. Anything here is granted for free and "
			+ "means nothing.", 12, COL_DIM))
		_content_pane.add_child(warning)

	if service.pending_count() > 0:
		_content_pane.add_child(_label(
			"  %d purchase(s) waiting to be confirmed — they will arrive once you are online"
			% service.pending_count(), 13, COL_ACCENT))

	# Cores as a CARD GRID, not a price list. What a player is comparing here is value
	# per pack, and a column of rows makes that a reading exercise: the amount has to be
	# the biggest thing on the card and the bonus has to be a badge, or the bigger packs
	# have no visible reason to exist.
	_content_pane.add_child(_label("  CORES", 15, COL_ACCENT))
	var packs := GridContainer.new()
	packs.columns = 3
	packs.add_theme_constant_override("h_separation", UIKit.SPACE_SM)
	packs.add_theme_constant_override("v_separation", UIKit.SPACE_SM)
	_content_pane.add_child(packs)
	for product: Variant in service.products("iap"):
		packs.add_child(_store_card(product as Dictionary, service, true))

	_content_pane.add_child(_label("  SPEND CORES", 15, COL_ACCENT))
	var spends := GridContainer.new()
	spends.columns = 3
	spends.add_theme_constant_override("h_separation", UIKit.SPACE_SM)
	spends.add_theme_constant_override("v_separation", UIKit.SPACE_SM)
	_content_pane.add_child(spends)
	for product: Variant in service.products("currency"):
		spends.add_child(_store_card(product as Dictionary, service, false))


## One product as a card: what you get, big; what it costs, on the button.
func _store_card(product: Dictionary, service: StoreService, real_money: bool) -> PanelContainer:
	var id: String = String(product.get("id", ""))
	var bonus: int = int(product.get("bonus_percent", 0))
	var owned: bool = bool(product.get("once_only", false)) and service.owns(id)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 150)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = UIKit.card(UIKit.SURFACE, UIKit.RADIUS_CARD,
		UIKit.SPACE_MD, UIKit.SPACE_MD)
	if bonus > 0:
		style.border_color = UIKit.GOLD
	card.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.SPACE_XS)
	card.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.SPACE_SM)
	box.add_child(head)
	var name_label := _label(String(product.get("name", id)), UIKit.SIZE_LABEL, COL_TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	if bonus > 0:
		# The only reason a larger pack exists. It has to be legible without arithmetic.
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", UIKit.plain(UIKit.GOLD, UIKit.RADIUS_PILL, 8, 2))
		badge.add_child(_label("+%d%%" % bonus, UIKit.SIZE_MICRO, Color("1a1206")))
		head.add_child(badge)

	box.add_child(_label(_reward_text(product.get("grants", {}) as Dictionary),
		UIKit.SIZE_TITLE, COL_GOLD))
	var blurb: String = String(product.get("text", ""))
	if not blurb.is_empty():
		var note := _label(blurb, UIKit.SIZE_MICRO, COL_DIM)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(note)

	var button: Button
	if owned:
		button = Button.new()
		button.text = "OWNED"
		button.disabled = true
	else:
		var price: String = service.price_of(product) if real_money \
			else "%d cores" % int(product.get("cost_amount", 0))
		var affordable: bool = real_money or Session.profile().can_afford(
			String(product.get("cost_currency", PlayerProfile.CORES)),
			int(product.get("cost_amount", 0)))
		if affordable:
			button = _big_button(price, _on_buy.bind(id) if real_money
				else _on_spend_cores.bind(id))
		else:
			button = Button.new()
			button.text = price
			button.disabled = true
	button.custom_minimum_size = Vector2(0, 38)
	box.add_child(button)
	return card


func _store_row(product: Dictionary, service: StoreService, real_money: bool) -> PanelContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _flat(COL_ROW, 5))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	row.add_child(line)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)

	var id: String = String(product.get("id", ""))
	var title: String = String(product.get("name", id))
	if int(product.get("bonus_percent", 0)) > 0:
		title += "   +%d%%" % int(product.get("bonus_percent", 0))
	text.add_child(_label(title, 15, COL_TEXT))
	text.add_child(_label(String(product.get("text", "")), 12, COL_DIM))
	text.add_child(_label(_reward_text(product.get("grants", {}) as Dictionary), 12, COL_GOLD))

	var owned: bool = bool(product.get("once_only", false)) and service.owns(id)
	var button := Button.new()
	if owned:
		button.text = "OWNED"
		button.disabled = true
	elif real_money:
		button.text = service.price_of(product)
	else:
		button.text = "%d cores" % int(product.get("cost_amount", 0))
		button.disabled = not Session.profile().can_afford(
			String(product.get("cost_currency", PlayerProfile.CORES)),
			int(product.get("cost_amount", 0)))
	button.custom_minimum_size = Vector2(150, 40)
	if not button.disabled:
		button.pressed.connect(_on_buy.bind(id) if real_money else _on_spend_cores.bind(id))
	line.add_child(button)
	return row


func _on_buy(product_id: String) -> void:
	Session.store_service.buy_iap(product_id, Session.now(),
		func(result: int, message: String) -> void:
			if result == Billing.Result.OK:
				Session.store.save()
				Audio.play("ui_confirm", -10.0)
				_flash("purchased", COL_GOOD)
			elif result == Billing.Result.CANCELLED:
				# Not an error. Telling a player who changed their mind that something
				# went wrong is how a store screen feels hostile.
				_flash("cancelled", COL_DIM)
			else:
				_flash(message, COL_WARN)
			_refresh_all())


func _on_spend_cores(product_id: String) -> void:
	var result: int = Session.store_service.buy_with_currency(product_id, Session.now())
	if result != ProfileCommand.Result.OK:
		_flash(ProfileCommand.result_name(result), COL_WARN)
		return
	Session.store.save()
	Audio.play("ui_confirm", -10.0)
	_flash("bought", COL_GOOD)
	_refresh_all()


# --- Colossus ----------------------------------------------------------------

func _fill_colossus() -> void:
	var service: CoopService = Session.coop
	var boss: Dictionary = service.current_boss()
	_content_pane.add_child(_section_header(
		"Colossus",
		"One machine, everybody's damage. You are not expected to win an attempt."))

	if boss.is_empty() or service.encounter == null:
		_content_pane.add_child(_label("  nothing is stirring in the yard right now", 14, COL_DIM))
		return

	var encounter: Colossus.Encounter = service.encounter

	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", _flat(Color("18222e"), 5, 16, 14))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	header.add_child(box)
	box.add_child(_label(String(boss.get("name", "Colossus")).to_upper(), 24, COL_GOLD))
	box.add_child(_label(String(boss.get("text", "")), 13, COL_DIM))

	# The bar is the point of the mode: it is the only thing in the game that other
	# people move while you are not playing.
	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.value = encounter.percent_remaining()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.add_theme_stylebox_override("background", _flat(Color("0d1014"), 3))
	bar.add_theme_stylebox_override("fill", _flat(COL_WARN, 3))
	box.add_child(bar)

	var hours: int = maxi(0, encounter.ends_at - Session.now()) / 3600
	box.add_child(_label("%d%% standing   ·   %s of %s hull   ·   %d days %d hours left" % [
		encounter.percent_remaining(), _big(encounter.hp_remaining), _big(encounter.hp_pool),
		hours / 24, hours % 24], 13, COL_DIM))
	_content_pane.add_child(header)

	var brief := PanelContainer.new()
	brief.add_theme_stylebox_override("panel", _flat(COL_ROW, 5))
	var brief_box := VBoxContainer.new()
	brief_box.add_theme_constant_override("separation", 2)
	brief.add_child(brief_box)
	brief_box.add_child(_label("HOW IT DIES", 14, COL_ACCENT))
	brief_box.add_child(_label(String(boss.get("brief", "")), 13, COL_TEXT))
	_content_pane.add_child(brief)

	_content_pane.add_child(_label("  TARGET PRIORITY", 15, COL_ACCENT))
	_content_pane.add_child(_colossus_board(boss, encounter))

	_content_pane.add_child(_guild_row())

	var yours := PanelContainer.new()
	yours.add_theme_stylebox_override("panel", _flat(COL_ROW, 5))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	yours.add_child(line)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	text.add_child(_label("Your contribution", 15, COL_TEXT))
	text.add_child(_label("%s damage   ·   %d of %d attempts left%s" % [
		_big(encounter.contributed), service.attempts_left(), CoopService.ATTEMPTS_PER_WINDOW,
		"   ·   %d others fighting" % encounter.contributors if encounter.contributors > 1 else ""],
		12, COL_DIM))

	var attack := Button.new()
	attack.text = "ATTEMPT" if service.attempts_left() > 0 else "NO ATTEMPTS LEFT"
	attack.disabled = service.attempts_left() <= 0 or encounter.is_defeated()
	attack.custom_minimum_size = Vector2(180, 38)
	attack.pressed.connect(_on_attempt_colossus)
	line.add_child(attack)
	_content_pane.add_child(yours)


## The colossus as a BOARD rather than a list.
##
## The mode is a target-priority puzzle -- the core takes 82% less damage while any limb
## stands, so opening on it wastes the attempt. A column of text rows states that; a board
## SHOWS it: four limbs across the top, the core beneath them, and the core visibly locked
## while any limb is alive. That is the whole decision the player has to make, and it
## should be readable without reading.
func _colossus_board(boss: Dictionary, encounter: Colossus.Encounter) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIKit.SPACE_SM)

	var limbs: Array = []
	var core: Dictionary = {}
	for entry: Variant in (boss.get("parts", []) as Array):
		var part: Dictionary = entry as Dictionary
		if bool(part.get("vital", false)) or String(part.get("role", "")) == "vital":
			core = part
		else:
			limbs.append(part)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_SM)
	column.add_child(row)
	for entry: Variant in limbs:
		var card: Control = _colossus_card(entry as Dictionary, false, false)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)

	if not core.is_empty():
		# Guarded for as long as ANY limb is standing. The encounter tracks one shared
		# hull rather than per-limb hulls, so "limbs still standing" is read from the
		# pool: the guard only lifts once the boss is nearly down.
		var guarded: bool = encounter.percent_remaining() > int(core.get("guard_until", 30))
		column.add_child(_colossus_card(core, true, guarded))
	return column


## One limb or core. Carries the chassis picture, so a player can see the thing they are
## being asked to break rather than read its name.
func _colossus_card(part: Dictionary, is_core: bool, guarded: bool) -> PanelContainer:
	var card := PanelContainer.new()
	var style: StyleBoxFlat = UIKit.card(
		UIKit.SURFACE_HIGH if is_core else UIKit.SURFACE, UIKit.RADIUS_CARD,
		UIKit.SPACE_MD, UIKit.SPACE_SM)
	if is_core:
		style.border_color = UIKit.TEXT_FAINT if guarded else UIKit.AMBER
	card.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.SPACE_XS)
	card.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.SPACE_SM)
	box.add_child(head)

	var parts: Dictionary = part.get("parts", {}) as Dictionary
	var chassis_id: String = String(parts.get("chassis", ""))
	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(72, 72)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var thumb_path: String = "res://art/thumbs/%s.png" % chassis_id
	if ResourceLoader.exists(thumb_path):
		picture.texture = load(thumb_path)
	head.add_child(picture)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(text)
	text.add_child(_label(String(part.get("name", "Segment")), 15,
		COL_GOLD if is_core else COL_TEXT))

	# The armour type is the actionable half: it says which damage type to bring, which
	# is a squad decision made before the attempt, not during it.
	var chassis: Dictionary = Session.content.parts.get(chassis_id, {})
	var armour: String = String(chassis.get("armor_type", "plate"))
	text.add_child(_label("%s armour" % armour, 12, COL_ACCENT))
	if is_core:
		text.add_child(_label(
			"GUARDED — 82% less damage while a limb stands" if guarded
				else "EXPOSED — hit it now", 12,
			UIKit.TEXT_FAINT if guarded else UIKit.AMBER))
	else:
		text.add_child(_label("%d%% of the hull" % int(part.get("hp_share", 20)), 12, COL_DIM))
	return card


func _colossus_part_row(part: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _flat(COL_ROW, 4))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	row.add_child(line)

	var is_core: bool = bool(part.get("vital", false))
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	text.add_child(_label(String(part.get("name", "Segment")), 14,
		COL_GOLD if is_core else COL_TEXT))

	# Naming the armour type is the actionable half of the puzzle: it tells the player
	# which damage type to bring, which is a squad decision made in the Foundry.
	var parts: Dictionary = part.get("parts", {}) as Dictionary
	var chassis: Dictionary = Session.content.parts.get(String(parts.get("chassis", "")), {})
	var armour: String = String(chassis.get("armor_type", "plate"))
	text.add_child(_label(
		("the core — armoured while any limb stands" if is_core
			else "limb — %d%% of its hull" % int(part.get("hp_share", 20)))
		+ "   ·   %s armour" % armour, 12, COL_DIM))
	return row


## Who the pool is shared with. Guilds do exactly one thing at launch and this is it —
## so the screen says which colossus you are actually chipping at, rather than leaving
## the player to guess whether their damage is going anywhere near their friends.
func _guild_row() -> PanelContainer:
	var service: GuildService = Session.guilds
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _flat(COL_ROW, 5))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	row.add_child(line)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)

	if not service.is_online():
		text.add_child(_label("Fighting alone", 15, COL_TEXT))
		text.add_child(_label(
			"offline — this colossus is your own copy, and the damage is yours", 12, COL_DIM))
		return row

	if service.has_guild():
		text.add_child(_label(String(service.guild.get("name", "Your guild")), 15, COL_TEXT))
		text.add_child(_label("%d of %d members   ·   everyone's damage comes off this pool" % [
			service.member_count(), GuildService.MAX_MEMBERS], 12, COL_DIM))
		var leave := Button.new()
		leave.text = "LEAVE"
		leave.custom_minimum_size = Vector2(120, 34)
		leave.pressed.connect(_on_leave_guild)
		line.add_child(leave)
		return row

	text.add_child(_label("No guild", 15, COL_TEXT))
	text.add_child(_label(
		"you are chipping at your own copy — join a guild and the pool is shared", 12, COL_DIM))
	var find := Button.new()
	find.text = "FIND A GUILD"
	find.custom_minimum_size = Vector2(170, 34)
	find.pressed.connect(_on_browse_guilds)
	line.add_child(find)
	return row


func _on_browse_guilds() -> void:
	Session.guilds.browse("", func(_ok: bool) -> void:
		if _current == "colossus":
			_refresh_all())
	if Session.guilds.browsable.is_empty():
		_flash("looking for guilds...", COL_DIM)
		return
	# Joining the largest is the right default: it is the one most likely to be active,
	# and a guild that never fights is the same as no guild.
	var best: Dictionary = Session.guilds.browsable[0] as Dictionary
	Session.guilds.join(String(best.get("id", "")), func(ok: bool, message: String) -> void:
		_flash("joined %s" % best.get("name", "") if ok else message,
			COL_GOOD if ok else COL_WARN)
		_refresh_all())


func _on_leave_guild() -> void:
	Session.guilds.leave(func(ok: bool, message: String) -> void:
		_flash("left the guild" if ok else message, COL_DIM if ok else COL_WARN)
		_refresh_all())


func _on_attempt_colossus() -> void:
	var p: PlayerProfile = Session.profile()
	if p.squad("main").is_empty() or not p.squad_is_valid("main"):
		_flash("your squad is not ready", COL_WARN)
		return
	if Session.coop.attempts_left() <= 0:
		_flash("no attempts left in this window", COL_WARN)
		return
	Analytics.milestone("colossus_attempt")
	Session.pending_boss = true
	Session.pending_defence = null
	Session.pending_node_id = ""
	Session.pending_floor = 0
	Session.pending_squad = "main"
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")


## Thousands separators. A boss with 900000 hull reads as noise; 900,000 reads as big.
func _big(value: int) -> String:
	var text: String = str(absi(value))
	var out: String = ""
	var count: int = 0
	for i: int in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if value < 0 else "") + out


# --- Ranked ------------------------------------------------------------------

func _fill_ranked() -> void:
	var p: PlayerProfile = Session.profile()
	var now: int = Session.now()
	var service: PvpService = Session.pvp
	var rating: int = service.rating()

	_content_pane.add_child(_section_header(
		"Ranked",
		"Asynchronous. You fight snapshots of other squads, and yours defends while you are away."))

	# Whether these opponents are real people or the game's own bots is a fact the player
	# is entitled to. Hiding it would make the first weeks of a live ladder a quiet lie.
	var online: bool = service.repository.is_online()
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 8)
	status.add_child(_label("●", 13, COL_GOOD if online else COL_DIM))
	status.add_child(_label(
		"connected — you are fighting other players' squads" if online
		else "offline — opponents are the game's own, and your results are scored locally",
		12, COL_DIM))
	_content_pane.add_child(status)
	if online and service.repository is NakamaPvpRepository:
		# Rate-limited internally, so calling it on every open costs nothing.
		(service.repository as NakamaPvpRepository).refresh(
			rating, 8, now, func(_changed: bool) -> void:
				if _current == "ranked":
					_refresh_all())

	# Standing: rating, tier, and progress to the next one.
	var standing := PanelContainer.new()
	standing.add_theme_stylebox_override("panel", _flat(Color("18222e"), 5, 16, 14))
	var standing_box := VBoxContainer.new()
	standing_box.add_theme_constant_override("separation", 4)
	standing.add_child(standing_box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 22)
	standing_box.add_child(head)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 1)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(left)
	left.add_child(_label(Ranked.tier_name(rating).to_upper(), 24, COL_GOLD))
	var record: Dictionary = service.record()
	left.add_child(_label("rating %d   ·   %d won / %d lost   ·   %d matches" % [
		rating, int(record["wins"]), int(record["losses"]), service.matches_played()], 13, COL_DIM))

	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.value = Ranked.tier_progress(rating)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.add_theme_stylebox_override("background", _flat(Color("0d1014"), 3))
	bar.add_theme_stylebox_override("fill", _flat(COL_GOLD, 3))
	left.add_child(bar)
	_content_pane.add_child(standing)

	# The season: which Condition every ranked match is fought under, and how long left.
	# This is the single most decision-relevant fact on the screen.
	var condition_id: String = Ranked.season_condition(now, Session.content)
	var condition: Dictionary = Session.content.conditions.get(condition_id, {})
	var hours: int = Ranked.seconds_until_season_end(now) / 3600
	var season := PanelContainer.new()
	season.add_theme_stylebox_override("panel", _flat(COL_ROW, 5))
	var season_box := VBoxContainer.new()
	season_box.add_theme_constant_override("separation", 2)
	season.add_child(season_box)
	season_box.add_child(_label("SEASON CONDITION  ·  %s" % String(condition.get("name", "none")),
		15, COL_ACCENT))
	season_box.add_child(_label(String(condition.get("text", "")), 12, COL_DIM))
	season_box.add_child(_label(
		"every ranked match is fought under this   ·   %d days %d hours remaining" % [
			hours / 24, hours % 24], 12, COL_DIM))
	_content_pane.add_child(season)

	# Your defence. A stale defence is a free win for everyone who attacks it.
	var mine: PvpRepository.Defence = service.repository.get_defence(service.player_id())
	var defence_row := PanelContainer.new()
	defence_row.add_theme_stylebox_override("panel", _flat(COL_ROW, 5))
	var defence_line := HBoxContainer.new()
	defence_line.add_theme_constant_override("separation", 14)
	defence_row.add_child(defence_line)
	var defence_text := VBoxContainer.new()
	defence_text.add_theme_constant_override("separation", 1)
	defence_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defence_line.add_child(defence_text)
	defence_text.add_child(_label("Your defence", 15, COL_TEXT))
	var squad_size: int = mine.squad.size() if mine != null else 0
	defence_text.add_child(_label(
		"%d constructs   ·   power %d%%   ·   runs on your saved doctrine" % [
			squad_size, Economy.squad_power(p, Session.content)], 12, COL_DIM))
	var update := Button.new()
	update.text = "UPDATE DEFENCE"
	update.custom_minimum_size = Vector2(200, 34)
	update.pressed.connect(_on_update_defence)
	defence_line.add_child(update)
	_content_pane.add_child(defence_row)

	_content_pane.add_child(_label("  OPPONENTS", 15, COL_ACCENT))
	for defence: PvpRepository.Defence in service.find_opponents(5):
		_content_pane.add_child(_opponent_row(defence, rating))

	_content_pane.add_child(_label("  LEADERBOARD", 15, COL_ACCENT))
	var place: int = 0
	for entry: PvpRepository.Defence in service.leaderboard(8):
		place += 1
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _flat(COL_ROW, 4))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		row.add_child(line)
		var is_me: bool = entry.id == service.player_id()
		line.add_child(_label("%d." % place, 13, COL_GOLD if place <= 3 else COL_DIM))
		var name_label := _label(entry.display_name + ("   (you)" if is_me else ""), 14,
			COL_GOOD if is_me else COL_TEXT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		line.add_child(_label("%s  ·  %d" % [Ranked.tier_name(entry.rating), entry.rating], 13, COL_DIM))
		_content_pane.add_child(row)


func _opponent_row(defence: PvpRepository.Defence, own_rating: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _flat(COL_ROW, 5))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	row.add_child(line)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	text.add_child(_label(defence.display_name, 15, COL_TEXT))

	# What you stand to gain or lose, shown BEFORE the fight. A ladder that hides the
	# stakes until afterwards is asking the player to guess.
	var gain: int = Ranked.rating_delta(own_rating, defence.rating, true, Session.pvp.matches_played())
	var loss: int = Ranked.rating_delta(own_rating, defence.rating, false, Session.pvp.matches_played())
	var mine: int = Economy.squad_power(Session.profile(), Session.content)
	var detail: String = "%s  ·  rating %d  ·  %d constructs  ·  their power %d%% vs your %d%%" % [
		Ranked.tier_name(defence.rating), defence.rating, defence.squad.size(), defence.power, mine]
	text.add_child(_label(detail, 12, COL_WARN if defence.power > mine + 25 else COL_DIM))
	text.add_child(_label("win +%d   ·   lose %d" % [gain, loss], 12, COL_GOLD))
	# The squad you are about to attack, as pictures. "6 constructs, power 118%" is the
	# summary of a decision; the frames they are actually built on are the decision --
	# four anchors is a very different fight from four marksmen at the same power.
	text.add_child(_thumb_strip(defence.squad, 34))

	var fight := Button.new()
	fight.text = "ATTACK"
	fight.custom_minimum_size = Vector2(130, 36)
	fight.pressed.connect(_on_attack.bind(defence))
	line.add_child(fight)
	return row


func _on_update_defence() -> void:
	Session.pvp.publish_defence()
	Session.store.save()
	Audio.play("ui_confirm", -12.0)
	_flash("defence updated", COL_GOOD)
	_refresh_all()


func _on_attack(defence: PvpRepository.Defence) -> void:
	var p: PlayerProfile = Session.profile()
	if p.squad("main").is_empty() or not p.squad_is_valid("main"):
		_flash("your squad is not ready", COL_WARN)
		return
	Analytics.milestone("pvp_attacked")
	Session.pending_defence = defence
	Session.pending_node_id = ""
	Session.pending_floor = 0
	Session.pending_squad = "main"
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")


# --- Gauntlet ----------------------------------------------------------------

func _fill_gauntlet() -> void:
	var p: PlayerProfile = Session.profile()
	var now: int = Session.now()
	var floor_number: int = Gauntlet.current_floor(p, now)

	_content_pane.add_child(_section_header(
		"Gauntlet",
		"Endless. Win to climb, lose and start again at floor 1. Best depth is kept forever."))

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _flat(Color("18222e"), 5, 16, 14))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 22)
	card.add_child(line)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	text.add_child(_label("FLOOR %d" % floor_number, 26, COL_TEXT))

	var enemies: int = Gauntlet.floor_squad(floor_number, Session.content).size()
	var enemy_power: int = Gauntlet.floor_power(floor_number)
	var mine: int = Economy.squad_power(p, Session.content)
	var condition_id: String = Gauntlet.floor_condition(floor_number, Session.content)
	var detail: String = "%d enemies   ·   their power %d%%   ·   your squad %d%%" % [
		enemies, enemy_power, mine]
	if not condition_id.is_empty():
		detail += "   ·   %s" % String(
			(Session.content.conditions.get(condition_id, {}) as Dictionary).get("name", condition_id))
	# Power is shown side by side deliberately: a player who loses should be able to see
	# whether they were outgunned or outplayed.
	text.add_child(_label(detail, 13, COL_WARN if enemy_power > mine + 20 else COL_DIM))
	text.add_child(_label("reward  +%d scrap" % Gauntlet.floor_reward(floor_number), 13, COL_GOLD))

	line.add_child(_big_button("CLIMB", _on_climb.bind(floor_number)))
	_content_pane.add_child(card)

	_content_pane.add_child(_label("  THE CLIMB", 15, COL_ACCENT))
	_content_pane.add_child(_gauntlet_ladder(floor_number, p))

	var stats := PanelContainer.new()
	stats.add_theme_stylebox_override("panel", _flat(COL_ROW, 5))
	var stat_line := HBoxContainer.new()
	stat_line.add_theme_constant_override("separation", 34)
	stats.add_child(stat_line)
	stat_line.add_child(_label("best depth   %d" % Gauntlet.best_depth(p), 14, COL_TEXT))
	stat_line.add_child(_label("this week   %d" % Gauntlet.week_best(p, now), 14, COL_DIM))
	stat_line.add_child(_label("resets in   %d h" % (Gauntlet.seconds_until_reset(now) / 3600), 14, COL_DIM))
	_content_pane.add_child(stats)


## The floors ahead, as a ladder.
##
## The mode is a tower and the screen showed exactly one rung of it, so "endless" was a
## word in the subtitle rather than something the player could see. Rendering the next
## several floors with their power and reward makes the curve visible -- and because
## floors are GENERATED from the floor number, these are the real opponents, not a
## decorative preview.
func _gauntlet_ladder(current: int, profile: PlayerProfile) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIKit.SPACE_XS)

	var best: int = Gauntlet.best_depth(profile)
	var mine: int = Economy.squad_power(profile, Session.content)

	for step: int in GAUNTLET_LADDER_ROWS:
		var floor_number: int = current + step
		var power: int = Gauntlet.floor_power(floor_number)

		var row := PanelContainer.new()
		var style: StyleBoxFlat = UIKit.plain(
			UIKit.SURFACE_HIGH if step == 0 else UIKit.SURFACE,
			UIKit.RADIUS_CONTROL, UIKit.SPACE_MD, UIKit.SPACE_SM)
		if step == 0:
			style.border_width_left = 3
			style.border_color = UIKit.AMBER
			style.corner_radius_top_left = 0
			style.corner_radius_bottom_left = 0
		row.add_theme_stylebox_override("panel", style)

		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", UIKit.SPACE_LG)
		row.add_child(line)

		var label: String = "FLOOR %d" % floor_number
		if floor_number == best + 1 and best > 0:
			label += "   · your record"
		var name_label := _label(label, UIKit.SIZE_LABEL,
			COL_TEXT if step == 0 else COL_DIM)
		name_label.custom_minimum_size = Vector2(190, 0)
		line.add_child(name_label)

		# Their power against yours, on every rung: this is the number that decides how
		# far the current squad can get, and it is the reason to go and upgrade.
		var gap := _label("power %d%%" % power, UIKit.SIZE_LABEL,
			COL_WARN if power > mine + 20 else COL_DIM)
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(gap)
		line.add_child(_label("+%d scrap" % Gauntlet.floor_reward(floor_number),
			UIKit.SIZE_LABEL, COL_GOLD if step == 0 else COL_DIM))
		column.add_child(row)
	return column


func _on_climb(floor_number: int) -> void:
	var p: PlayerProfile = Session.profile()
	if p.squad("main").is_empty() or not p.squad_is_valid("main"):
		_flash("your squad is not ready", COL_WARN)
		return
	Session.pending_floor = floor_number
	Session.pending_node_id = ""
	Session.pending_squad = "main"
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")


# --- Parts -------------------------------------------------------------------

func _fill_parts() -> void:
	var p: PlayerProfile = Session.profile()
	_content_pane.add_child(_section_header(
		"Parts", "Fit parts to a construct and see it. Scrap raises LEVEL; only a REFIT raises TIER, and tier is what raises the level cap."))
	if p.inventory().is_empty():
		_content_pane.add_child(_label("  no parts yet", 14, COL_DIM))
		return

	# The loadout editor is the screen; the upgrade list below it is the bookkeeping.
	# Equipping used to be impossible here, which made the whole modular part system
	# something the player could read about but never actually use.
	var loadout := LoadoutScreen.new()
	loadout.custom_minimum_size = Vector2(0, 520)
	loadout.changed.connect(_refresh_currencies)
	_content_pane.add_child(loadout)

	_content_pane.add_child(_label("  UPGRADE", 13, COL_DIM))
	for part_id: String in p.owned_part_ids():
		_content_pane.add_child(_part_row(part_id, p))


func _part_row(part_id: String, p: PlayerProfile) -> PanelContainer:
	var definition: Dictionary = Session.content.parts.get(part_id, {})

	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _flat(COL_ROW, 5))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	row.add_child(line)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	text.add_child(_label("%s   ·   %s" % [
		String(definition.get("name", part_id)), String(definition.get("slot", ""))], 15, COL_TEXT))

	var capped: bool = p.is_max_level(part_id)
	var stat_line: String = "level %d of %d   ·   tier %d   ·   %d duplicate%s" % [
		p.part_level(part_id), p.level_cap(part_id), p.part_tier(part_id),
		p.part_copies(part_id), "" if p.part_copies(part_id) == 1 else "s"]
	if capped:
		stat_line += "   ·   at its cap — refit to go further"
	text.add_child(_label(stat_line, 12, COL_GOLD if capped else COL_DIM))

	var level_button := Button.new()
	level_button.custom_minimum_size = Vector2(190, 34)
	if capped:
		level_button.text = "AT CAP"
		level_button.disabled = true
	else:
		level_button.text = "LEVEL   %d scrap" % Economy.level_cost(p, part_id, Session.content)
		level_button.disabled = Session.store.can_execute(
			ProfileCommands.LevelPart.new(part_id)) != ProfileCommand.Result.OK
		level_button.pressed.connect(_on_level_part.bind(part_id))
	line.add_child(level_button)

	var refit_button := Button.new()
	refit_button.custom_minimum_size = Vector2(210, 34)
	if p.part_tier(part_id) >= PlayerProfile.MAX_TIER:
		refit_button.text = "MAX TIER"
		refit_button.disabled = true
	else:
		refit_button.text = "REFIT   %d dupes + %d alloy" % [
			Economy.refit_copies(p, part_id), Economy.refit_alloy(p, part_id, Session.content)]
		refit_button.disabled = Session.store.can_execute(
			ProfileCommands.RefitPart.new(part_id)) != ProfileCommand.Result.OK
		refit_button.pressed.connect(_on_refit_part.bind(part_id))
	line.add_child(refit_button)
	return row


func _on_level_part(part_id: String) -> void:
	_after(Session.store.execute(ProfileCommands.LevelPart.new(part_id)), "levelled")


func _on_refit_part(part_id: String) -> void:
	_after(Session.store.execute(ProfileCommands.RefitPart.new(part_id)), "refit")


# --- Crates ------------------------------------------------------------------

func _fill_crates() -> void:
	_content_pane.add_child(_section_header(
		"Crates", "Odds are printed on every crate. A guaranteed drop fires if you go unlucky too long."))

	var ids: Array = Session.content.crates.keys()
	ids.sort()
	for crate_id: Variant in ids:
		var crate: Dictionary = Session.content.crates[crate_id]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _flat(COL_ROW, 5))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		row.add_child(box)

		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 14)
		box.add_child(head)

		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 1)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(text)
		text.add_child(_label(String(crate["name"]), 16, COL_TEXT))
		text.add_child(_label(String(crate.get("text", "")), 12, COL_DIM))

		# Primary, like FIGHT and COLLECT. Three crates are three equivalent choices
		# rather than competing priorities, so they can all carry the action colour.
		var open: Button = _big_button(
			"OPEN   %d %s" % [int(crate["cost_amount"]), String(crate["cost_currency"])],
			_on_open_crate.bind(String(crate_id)))
		open.custom_minimum_size = Vector2(210, 40)
		open.disabled = Session.store.can_execute(
			ProfileCommands.OpenCrate.new(String(crate_id))) != ProfileCommand.Result.OK
		head.add_child(open)

		var counters: Dictionary = (Session.profile().data["crates"] as Dictionary)["counters"]
		var since: int = int((counters.get(crate_id, {}) as Dictionary).get("since_pity", 0))
		box.add_child(_odds_bar(crate))
		box.add_child(_pity_row(crate, since))
		_content_pane.add_child(row)


## Published odds as a proportional BAR, built from the same weights the roll uses.
##
## The odds were a line of 11 px grey text. They are a legal requirement in several
## markets and a store-policy requirement everywhere, and more to the point they are the
## only honest thing a crate can tell you -- printing them at a size nobody reads is
## technically compliant and practically a dodge. A bar shows at a glance that a rare
## drop is a sliver.
func _odds_bar(crate: Dictionary) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIKit.SPACE_XS)
	column.add_child(_label("PUBLISHED ODDS", UIKit.SIZE_MICRO, COL_DIM))

	var total: int = 0
	for entry: Variant in crate.get("rates", []):
		total += int((entry as Dictionary).get("weight", 0))
	if total <= 0:
		return column

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)
	bar.custom_minimum_size = Vector2(0, 16)
	column.add_child(bar)

	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", UIKit.SPACE_MD)
	column.add_child(legend)

	for entry: Variant in crate.get("rates", []):
		var rate: Dictionary = entry as Dictionary
		var weight: int = int(rate.get("weight", 0))
		var rarity: int = int(rate.get("rarity", 1))
		var colour: Color = RARITY_COLOURS.get(rarity, COL_DIM)

		var segment := PanelContainer.new()
		segment.add_theme_stylebox_override("panel", UIKit.plain(colour, 3))
		# Stretch ratio IS the weight, so the bar cannot drift from the real odds.
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.size_flags_stretch_ratio = float(weight)
		bar.add_child(segment)

		var tag := HBoxContainer.new()
		tag.add_theme_constant_override("separation", UIKit.SPACE_XS)
		legend.add_child(tag)
		var dot := PanelContainer.new()
		dot.custom_minimum_size = Vector2(9, 9)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel", UIKit.plain(colour, 2))
		tag.add_child(dot)
		tag.add_child(_label("rarity %d  ·  %d.%d%%" % [
			rarity, (weight * 100) / total, ((weight * 1000) / total) % 10],
			UIKit.SIZE_MICRO, COL_DIM))
	return column


## The pity counter, as progress toward a promise rather than a number in a sentence.
func _pity_row(crate: Dictionary, since: int) -> Control:
	var after: int = int(crate.get("pity_after", 0))
	if after <= 0:
		return _label(" ", UIKit.SIZE_MICRO, COL_DIM)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIKit.SPACE_XS)
	var left: int = maxi(0, after - since)
	column.add_child(_label(
		"guaranteed rarity %d in %d more %s" % [
			int(crate.get("pity_rarity", 3)), left, "open" if left == 1 else "opens"],
		UIKit.SIZE_MICRO, COL_GOLD if left <= 3 else COL_DIM))

	var bar := ProgressBar.new()
	bar.max_value = after
	bar.value = since
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 6)
	bar.add_theme_stylebox_override("background", UIKit.plain(UIKit.SURFACE_SUNK, 3))
	bar.add_theme_stylebox_override("fill", UIKit.plain(COL_GOLD, 3))
	column.add_child(bar)
	return column


func _on_open_crate(crate_id: String) -> void:
	var command := ProfileCommands.OpenCrate.new(crate_id)
	var result: int = Session.store.execute(command)
	if result != ProfileCommand.Result.OK:
		_after(result, "")
		return
	var names: PackedStringArray = []
	for pull: Crates.Pull in command.pulls:
		var part: Dictionary = Session.content.parts.get(pull.part_id, {})
		names.append("%s%s" % [String(part.get("name", pull.part_id)), " (dupe)" if pull.was_duplicate else ""])
	Analytics.milestone("crate_opened")
	Audio.play("ui_confirm", -8.0)
	Session.store.save()
	_flash("opened: " + ", ".join(names), COL_GOOD)
	_refresh_all()


# --- Doctrine ----------------------------------------------------------------

func _fill_doctrine() -> void:
	_content_pane.add_child(_section_header(
		"Doctrine", "Checked top to bottom, first match wins. Order is the whole thing."))
	var editor := DoctrineEditor.new()
	editor.custom_minimum_size = Vector2(0, 560)
	editor.doctrine_saved.connect(_on_doctrine_saved)
	editor.load_rules((Session.profile().data["doctrines"] as Dictionary).get("main", []))
	_content_pane.add_child(editor)


func _on_doctrine_saved(rules: Array) -> void:
	_after(Session.store.execute(ProfileCommands.SetDoctrine.new("main", rules)), "doctrine saved")


# --- First run ---------------------------------------------------------------

## Shown once, then never again. A welcome that explains the loop in four lines beats a
## multi-screen tutorial nobody reads, and it beats nothing at all by a mile.
func _maybe_first_run() -> void:
	var seen: Array = (Session.profile().data.get("seen_tips", []) as Array)
	if seen.has("welcome"):
		return
	_mark_seen("welcome")

	# A scrim, so the welcome reads as modal instead of floating over live content the
	# player might try to click through.
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.72)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_CENTER)
	overlay.custom_minimum_size = Vector2(760, 0)
	overlay.offset_left = -380
	overlay.offset_right = 380
	overlay.offset_top = -190
	overlay.offset_bottom = 190
	overlay.add_theme_stylebox_override("panel", _flat(Color("1d2836"), 8, 26, 22))
	add_child(overlay)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	overlay.add_child(box)

	box.add_child(_label("You are a Reclaimer.", 24, COL_TEXT))
	var body := _label(
		"Constructs are built from PARTS — a chassis, a core, two arms and a module. "
		+ "The parts decide how a construct fights and how far it can reach.\n\n"
		+ "In battle the fight runs on its own and freezes every six seconds so you can "
		+ "give orders. You never control a construct directly.\n\n"
		+ "Between fights: collect what your yard made, spend scrap on parts, take the next node.\n\n"
		+ "The card at the top of the screen always tells you the best thing to do next.",
		14, COL_DIM)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)

	var dismiss := Button.new()
	dismiss.text = "START"
	dismiss.custom_minimum_size = Vector2(0, 46)
	dismiss.pressed.connect(func() -> void:
		scrim.queue_free()
		overlay.queue_free())
	box.add_child(dismiss)


## A one-line prompt the first time each section is opened. Inline, not hover -- there
## is no hover on a phone.
func _maybe_show_section_tip(id: String) -> void:
	var seen: Array = (Session.profile().data.get("seen_tips", []) as Array)
	if seen.has(id):
		return
	_mark_seen(id)
	_help_visible = true
	_refresh_help()


func _mark_seen(key: String) -> void:
	var data: Dictionary = Session.profile().data
	if not data.has("seen_tips"):
		data["seen_tips"] = []
	var seen: Array = data["seen_tips"]
	if not seen.has(key):
		seen.append(key)
		Session.store.save()


# --- Shared ------------------------------------------------------------------

func _after(result: int, verb: String) -> void:
	if result != ProfileCommand.Result.OK:
		Audio.play("ui_deny", -12.0)
		_flash(ProfileCommand.result_name(result), COL_WARN)
		return
	Audio.play("ui_confirm", -12.0)
	match verb:
		"collected": Analytics.milestone("collected")
		"levelled": Analytics.milestone("part_levelled")
	Session.store.save()
	if not verb.is_empty():
		_flash(verb, COL_GOOD)
	_refresh_all()


func _show_result_toast() -> void:
	if Session.last_pass_xp > 0:
		_flash("+%d season xp" % Session.last_pass_xp, COL_ACCENT)

	if Session.last_rewards.has("score"):
		_flash("%s points   ·   your best attempt is the one that counts"
			% _big(int(Session.last_rewards["score"])), COL_GOLD)
		return
	if Session.last_rewards.has("boss_damage"):
		_flash("%s damage to the colossus   ·   %d%% standing   ·   +%d scrap" % [
			_big(int(Session.last_rewards["boss_damage"])),
			int(Session.last_rewards.get("boss_percent", 100)),
			int(Session.last_rewards.get("scrap", 0))], COL_GOLD)
		return
	if Session.last_rewards.has("rating"):
		var delta: int = int(Session.last_rewards["rating"])
		_flash("%s   ·   %+d rating   ·   %s" % [
			"VICTORY" if Session.last_result_won else "DEFEAT",
			delta, String(Session.last_rewards.get("tier", ""))],
			COL_GOOD if Session.last_result_won else COL_WARN)
		return
	if Session.last_result_won:
		var text: String = "VICTORY   +%d scrap" % int(Session.last_rewards.get("scrap", 0))
		var alloy: int = int(Session.last_rewards.get("alloy", 0))
		if alloy > 0:
			text += "   +%d alloy" % alloy
		if int(Session.last_rewards.get("new_parts", 0)) > 0:
			text += "   + new part"
		_flash(text, COL_GOOD)
	else:
		_flash("DEFEAT — salvage recovered. Upgrade a part and try again.", COL_WARN)


func _flash(text: String, colour: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", colour)
	_toast.modulate = Color(1, 1, 1, 1)
	var tween := create_tween()
	tween.tween_interval(4.0)
	tween.tween_property(_toast, "modulate:a", 0.0, 1.2)


func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Every panel and button background in the hub comes through here.
##
## It now returns a real card -- hairline border, lighter top edge, soft drop shadow --
## instead of a bare rectangle of colour. Routing all thirty-nine call sites through one
## helper is what makes that a single edit rather than a week of touching every screen.
##
## A radius of 0 still means "part of the page" (headers, bars, wells), so those stay
## flat and borderless; anything with a corner radius is an OBJECT on the page and gets
## the full treatment.
func _flat(colour: Color, radius: int, margin_x: int = 12, margin_y: int = 9) -> StyleBoxFlat:
	if radius <= 0:
		return UIKit.plain(colour, 0, margin_x, margin_y)
	return UIKit.inset(colour, maxi(radius, UIKit.RADIUS_CONTROL), margin_x, margin_y)


## The selected nav item: a raised surface with a solid amber bar down its leading edge.
##
## A bar rather than a fill, because "which screen am I on" has to survive being glanced
## at. A slightly-lighter background does not -- it was the previous treatment and it read
## as a hover state at best.
func _nav_selected() -> StyleBoxFlat:
	var style := UIKit.plain(UIKit.SURFACE_HIGH, UIKit.RADIUS_CONTROL, 12, 8)
	style.border_width_left = 3
	style.border_color = UIKit.AMBER
	# Square off the leading corners so the bar reads as an edge marker rather than as a
	# stripe floating inside a rounded box.
	style.corner_radius_top_left = 0
	style.corner_radius_bottom_left = 0
	return style


## Dev-only: `--shot <path> [--section id] [--after <frames>]` renders the hub and exits.
##
## `--after` matters more than it looks: three frames is before any network reply can
## have arrived, so a shot of the ranked screen taken immediately always shows the
## offline state no matter what the server is doing.
func _maybe_capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find("--shot")
	if index < 0 or index + 1 >= args.size():
		return
	var section: int = args.find("--section")
	if section >= 0 and section + 1 < args.size():
		_current = args[section + 1]
		_refresh_all()
	var frames: int = 3
	var after: int = args.find("--after")
	if after >= 0 and after + 1 < args.size():
		frames = maxi(3, int(args[after + 1]))
	for _i: int in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[index + 1])
	get_tree().quit()
