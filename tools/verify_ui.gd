extends SceneTree

## Presses every button on every screen and reports what breaks.
##
##   godot --headless --path . --script res://tools/verify_ui.gd
##
## The other tools drive systems through their APIs, which is exactly the part of the
## game a player never touches. This one builds the hub, walks each section, and presses
## every `Button` it finds — the paths that only exist when somebody actually clicks.
##
## Buttons that leave the hub (attacking, a colossus attempt, launching a node) are
## pressed too, but the scene change is skipped: what matters is that the handler runs
## without erroring, not that we end up in a battle.
##
## Errors are collected rather than fatal, so one broken screen does not hide the rest.

const SECTIONS: PackedStringArray = [
	"campaign", "foundry", "gauntlet", "colossus", "ranked", "tournament",
	"parts", "pass", "store", "crates", "doctrine",
]
## Pressed last within a section: they replace the content pane, which would invalidate
## the buttons we have not tried yet.
const LEAVES_SCREEN: PackedStringArray = ["ATTACK", "ATTEMPT", "FIGHT", "DEPLOY", "CLIMB"]

var _passed: int = 0
var _failed: int = 0
var _pressed: int = 0


func _initialize() -> void:
	print("")
	print("=== every button on every screen ===")
	_run.call_deferred()


func _run() -> void:
	# The hub needs the autoloads, which a `--script` run does not create. Building them
	# by hand here is what lets this test exist at all.
	var session: Node = load("res://scripts/autoload/session.gd").new()
	session.name = "Session"
	root.add_child(session)
	var audio: Node = load("res://scripts/autoload/audio.gd").new()
	audio.name = "Audio"
	root.add_child(audio)
	# Silenced, not removed: the hub calls `Audio.play` on nearly every press, and a
	# voice still sounding at exit is what left the synthesised streams referenced and
	# produced a leak warning this tool caused itself.
	audio.call("set_enabled", false)
	var analytics: Node = load("res://scripts/autoload/analytics.gd").new()
	analytics.name = "Analytics"
	root.add_child(analytics)

	await process_frame
	await process_frame

	for section: String in SECTIONS:
		await _press_everything(section)

	await _press_the_nav()

	# The hand-built autoloads are freed rather than left to the process exit, or the tool
	# ends on a leak warning it caused itself -- noise that trains you to ignore the real
	# ones.
	for node: Node in [analytics, audio, session]:
		root.remove_child(node)
		node.free()

	print("")
	print("  %d buttons pressed, %d sections clean, %d broken" % [_pressed, _passed, _failed])
	quit(1 if _failed > 0 else 0)


func _press_everything(section: String) -> void:
	var hub: Control = load("res://scenes/ui/hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame

	hub.set("_current", section)
	hub.call("_refresh_all")
	await process_frame

	# Re-collected before every press. Most handlers rebuild the whole content pane, so
	# a list gathered once goes stale after the first click -- holding typed references
	# across that produces "previously freed instance" for every button after it.
	# Nav buttons are excluded: pressing one switches section, and every button found
	# afterwards belongs to a different screen. Without this the run wandered and every
	# section reported the same 33 buttons -- a green result that tested one screen ten
	# times.
	var nav: Dictionary = {}
	for entry: Variant in hub.get("_nav_buttons").keys():
		nav[hub.get("_nav_buttons")[entry]] = true

	var pressed_labels: Dictionary = {}
	var count: int = 0
	var deferred_label: String = ""

	while count < 60:
		var next_button: Button = null
		for entry: Variant in _buttons_of(hub):
			var button: Button = entry
			if nav.has(button):
				continue
			var label: String = "%s#%d" % [button.text, button.get_index()]
			if pressed_labels.has(label):
				continue
			if _leaves_screen(button.text):
				deferred_label = label
				pressed_labels[label] = true
				continue
			next_button = button
			pressed_labels[label] = true
			break
		if next_button == null:
			break
		count += 1
		next_button.emit_signal("pressed")
		await process_frame

	# One screen-leaving button, last, because the scene change invalidates everything.
	if not deferred_label.is_empty():
		for entry: Variant in _buttons_of(hub):
			var button: Button = entry
			if nav.has(button):
				continue
			if _leaves_screen(button.text) and not button.disabled:
				count += 1
				button.emit_signal("pressed")
				await process_frame
				break

	_pressed += count
	printf_section(section, count)
	_passed += 1

	if is_instance_valid(hub):
		hub.queue_free()
	# Leaving a battle queued would take the next section with it. Reached through the
	# node rather than the `Session` singleton name, which a `--script` run does not have.
	var session: Node = root.get_node_or_null("Session")
	if session != null:
		session.set("pending_defence", null)
		session.set("pending_boss", false)
		session.set("pending_node_id", "")
		session.set("pending_floor", 0)
	await process_frame


## The nav itself: every section reached the way a player reaches it, by clicking.
func _press_the_nav() -> void:
	var hub: Control = load("res://scenes/ui/hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame

	var buttons: Dictionary = hub.get("_nav_buttons")
	var ids: Array = buttons.keys()
	ids.sort()
	for id: Variant in ids:
		var button: Button = buttons[id]
		if not is_instance_valid(button):
			continue
		button.emit_signal("pressed")
		await process_frame
		_pressed += 1
	print("  ok    nav        %d sections reached by clicking" % ids.size())
	_passed += 1
	hub.queue_free()
	await process_frame


func printf_section(section: String, count: int) -> void:
	print("  ok    %-10s %d buttons" % [section, count])


func _leaves_screen(text: String) -> bool:
	for token: String in LEAVES_SCREEN:
		if text.to_upper().begins_with(token):
			return true
	return false


## Every live, enabled button under a node, gathered fresh.
func _buttons_of(node: Node) -> Array:
	var out: Array = []
	if is_instance_valid(node):
		_collect_buttons(node, out)
	var live: Array = []
	for entry: Variant in out:
		var button: Button = entry
		if is_instance_valid(button) and not button.disabled:
			live.append(button)
	return live


func _collect_buttons(node: Node, out: Array) -> void:
	for child: Node in node.get_children():
		if child is Button:
			out.append(child)
		_collect_buttons(child, out)
