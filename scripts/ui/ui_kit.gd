class_name UIKit
extends RefCounted

## The one place Scrapline's interface is described.
##
## Both the hub and the in-battle HUD build their controls from here, because two screens
## that style themselves independently drift apart on exactly the details a player reads
## as polish: corner radius, hairline colour, how far a pressed button moves, what "dim
## text" means this week.
##
## Ink & Rust (016): the whole interface is comic panels -- paper cards with heavy ink borders
## and hard offset shadows on a dark night page, ink lettering, one amber action per screen.
## The play-test 6 verdict on the fight's style frame was "apply this look to the entire game".
##
## The constant NAMES are the old ones, so no call site moved; their values are now paper and
## ink. What changed meaning: SURFACE is paper, TEXT is ink, HAIRLINE is a full ink line. Text
## that sits on the dark page or over the 3D world (titles, the map's labels) uses `PAGE_TEXT`
## with an ink outline instead (`on_page`).
##
## Colour is used as a signal, not as decoration:
##
##   AMBER   the primary action on a screen. One per screen. Also the selection mark.
##   BLUE    information and the player's own side (a dark blue that reads on paper).
##   GREEN   gains, things already earned.
##   RED     danger, costs, losses.
##   GOLD    rust: heat and machine condition, rare parts on cards.

# --- Surfaces ----------------------------------------------------------------
const BG := Color("10131a")          ## The page behind everything: the yard at night.
const BG_TOP := Color("171c28")      ## Backdrop, overhead.
const BG_GLOW := Color("1d1b22")     ## Backdrop, underfoot.
const SURFACE := Color("f7efdc")     ## A paper card on the page.
const SURFACE_HIGH := Color("efe3c8") ## A card on a card, or a hover state.
const SURFACE_SUNK := Color("d9ceb6") ## Wells: progress tracks, input fields, a card that cannot act.
const HAIRLINE := Color("14110f")    ## Card edges: the ink line.
const EDGE_LIGHT := Color("3a3533")

# --- Ink -----------------------------------------------------------------------
const TEXT := Color("14110f")        ## Ink, on paper.
const TEXT_DIM := Color("5b5247")
const TEXT_FAINT := Color("9a8f7e")
const PAGE_TEXT := Color("efe3c8")   ## Paper lettering, on the dark page or the 3D world.

# --- Signals -----------------------------------------------------------------
const AMBER := Color("ffc43d")       ## Primary action.
const AMBER_DEEP := Color("c9922a")
const BLUE := Color("1f6a8f")
const GREEN := Color("4d7f1d")
const RED := Color("b3261e")
## Rust, despite the name: heat and machine condition, rare parts on cards.
const GOLD := Color("b4532a")

# --- Ink & Rust (015) ---------------------------------------------------------
#
# The comic-panel kit: paper cards with ink borders and hard offset shadows, ink text, a
# narrator's caption for hints. The combat HUD is built from it; every other screen follows
# once the style frame is approved (docs/iterations/015-ink-style-frame.md).
const INK := Color("14110f")
const PAPER := Color("efe3c8")
const PAPER_CARD := Color("f7efdc")
const PAPER_DIM := Color("d9ceb6")   ## A card that cannot be pressed now.
const INK_DIM := Color("5b5247")     ## Secondary text on paper.
const INK_FAINT := Color("9a8f7e")
const CAPTION := Color("f2e2a4")     ## The narrator's box: hints and the coach.
const INK_LINK := Color("1f6a8f")    ## A glossary link on paper: your blue, dark enough to read.
const INK_RED := Color("b3261e")     ## Danger and costs, printed on paper.
const INK_GREEN := Color("4d7f1d")   ## Gains, printed on paper.

# --- Spacing -----------------------------------------------------------------
#
# A 4-point scale. Every gap in the game is one of these six numbers; "roughly 15px
# because it looked right" is what makes an interface feel assembled rather than designed.
const SPACE_XS: int = 4
const SPACE_SM: int = 8
const SPACE_MD: int = 12
const SPACE_LG: int = 18
const SPACE_XL: int = 26
const SPACE_XXL: int = 38

# --- Type scale --------------------------------------------------------------
#
# One step up from the old scale: both faces are condensed, so the same size sets
# narrower and lighter than the grotesque it replaced.
const SIZE_DISPLAY: int = 44
const SIZE_TITLE: int = 23
const SIZE_HEADING: int = 18
const SIZE_BODY: int = 16
const SIZE_LABEL: int = 14
const SIZE_MICRO: int = 12

# --- Shape -------------------------------------------------------------------
#
# Cut plate, not a rounded card. A 12 px radius is the corner of every web dashboard;
# a machine's panels are sheared steel with the edge barely broken.
const RADIUS_CARD: int = 3
const RADIUS_CONTROL: int = 2
const RADIUS_PILL: int = 999

const _FONT_DIR := "res://art/fonts/"

## Cached so a screen rebuild does not allocate a font per label.
static var _font: Font
static var _font_strong: Font
static var _font_display: Font
static var _font_numbers: Font
static var _font_comic: Font
static var _font_letters: Font
static var _theme: Theme


## The body face: Barlow Semi Condensed.
##
## Bundled, with its OFL licence beside it in `art/fonts/`. The SystemFont stack it replaced
## avoided shipping a licence, and paid for that by landing on Inter or SF on every
## platform -- the face of every app menu, which is the first thing that made the hub read
## as generated. Barlow is drawn from highway and industrial signage, which is what the
## lettering in a yard actually is.
static func font() -> Font:
	if _font == null:
		_font = _load("BarlowSemiCondensed-Regular.ttf")
	return _font


## Buttons and anything the eye should catch before it reads.
static func font_strong() -> Font:
	if _font_strong == null:
		_font_strong = _load("BarlowSemiCondensed-SemiBold.ttf")
	return _font_strong


## The display face: Anton since 016, the comic's title lettering (the stencil face it
## replaced belonged to the photographed look). Screen titles, names, buttons, numbers.
static func font_display() -> Font:
	if _font_display == null:
		_font_display = font_comic()
	return _font_display


## Readouts: tabular figures, so a number that ticks up does not shuffle the row.
static func font_numbers() -> Font:
	if _font_numbers == null:
		var face := FontVariation.new()
		face.base_font = _load("BarlowSemiCondensed-Medium.ttf")
		face.opentype_features = {_tag("tnum"): 1}
		_font_numbers = face
	return _font_numbers


## Ink & Rust (015): Anton, the heavy condensed face for headings, names, numbers and the
## buttons that matter -- comic-book title lettering. SIL OFL 1.1, `art/fonts/OFL-Anton.txt`.
static func font_comic() -> Font:
	if _font_comic == null:
		_font_comic = _load("Anton-Regular.ttf")
	return _font_comic


## Ink & Rust (015): Bangers, hand-lettered sound effects (KRANG, BOOM) and nothing else --
## the lettering is only worth anything while it is rare. SIL OFL 1.1, `art/fonts/OFL-Bangers.txt`.
static func font_letters() -> Font:
	if _font_letters == null:
		_font_letters = _load("Bangers-Regular.ttf")
	return _font_letters


static func _tag(name: String) -> int:
	return TextServerManager.get_primary_interface().name_to_tag(name)


static func _load(file: String) -> FontFile:
	var face: FontFile = load(_FONT_DIR + file) as FontFile
	# Hinting off and subpixel positioning on: at these sizes hinting snaps stems to the
	# pixel grid and the result reads as a system dialog.
	face.hinting = TextServer.HINTING_NONE
	face.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_ONE_HALF
	return face


## Ink & Rust (015): a comic panel -- `fill` inside a 3 px ink border, on a hard shadow.
static func ink_card(fill: Color = PAPER_CARD, margin_x: int = SPACE_LG, margin_y: int = SPACE_MD,
		shadow: int = 5) -> InkBox:
	var box := InkBox.new(fill, margin_x, margin_y)
	box.shadow = Vector2(shadow, shadow)
	return box


## A comic button. Pressed, it loses its shadow and drops into the place the shadow was.
static func ink_button(fill: Color, pressed: bool = false, lean: float = 0.0) -> InkBox:
	var box := InkBox.new(fill, SPACE_LG, SPACE_SM)
	box.skew = lean
	if pressed:
		box.shadow = Vector2.ZERO
		box.content_margin_left += 3
		box.content_margin_top += 3
	else:
		box.shadow = Vector2(4, 4)
	return box


## The narrator's caption (hints, the coach): pale yellow, ink-bordered, no shadow.
## 039, the comic: a screen's title as a CAPTION BOX -- hand-lettered (the comic face) in ink on
## the caption paper, a heavy border and a hard shadow, set at a slant the way a comic's caption is
## pasted on. `tilt` in degrees.
static func caption_title(text: String, size: int = 46, tilt: float = -2.0) -> Control:
	var box := PanelContainer.new()
	var style: InkBox = InkBox.new(CAPTION, SPACE_LG, 2)
	style.border_width = 4.0
	style.shadow = Vector2(6, 6)
	box.add_theme_stylebox_override("panel", style)
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font_comic())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", INK)
	box.add_child(label)
	box.rotation_degrees = tilt
	return box


static func ink_caption(margin_x: int = SPACE_MD, margin_y: int = SPACE_XS + 2) -> InkBox:
	var box := InkBox.new(CAPTION, margin_x, margin_y)
	box.shadow = Vector2(3, 3)
	box.border_width = 2.0
	return box


## A card: the default surface for a group of related things -- paper, a heavy ink border,
## and a hard shadow. `StyleBoxFlat` blurs its shadow by `shadow_size`, so the size is 1: an
## offset block with a one-pixel edge, which reads as the cut-out the style wants. (`InkBox`
## draws the same thing exactly and adds bands and halftone; this stays a `StyleBoxFlat`
## because screens tweak its colours and borders.)
static func card(fill: Color = SURFACE, radius: int = 0,
		margin_x: int = SPACE_LG, margin_y: int = SPACE_MD) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(0)
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	style.set_border_width_all(3)
	style.border_color = HAIRLINE
	style.shadow_color = HAIRLINE
	style.shadow_size = 1
	style.shadow_offset = Vector2(5, 5)
	style.anti_aliasing = false
	return style


## A card with no shadow, for surfaces already inside another card. Nested shadows stack
## into mud.
static func inset(fill: Color = SURFACE_HIGH, radius: int = 0,
		margin_x: int = SPACE_MD, margin_y: int = SPACE_SM) -> StyleBoxFlat:
	var style := card(fill, radius, margin_x, margin_y)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	style.set_border_width_all(2)
	return style


## A flat fill with no border or shadow -- backgrounds, bars, and anything that should
## read as part of the page rather than as an object on it.
static func plain(fill: Color, radius: int = 0,
		margin_x: int = 0, margin_y: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	style.anti_aliasing = true
	return style


## The primary action: amber, ink-bordered, on its shadow -- the only saturated block on a
## screen, so the eye lands on it first.
static func primary(fill: Color = AMBER) -> StyleBoxFlat:
	var style := card(fill, 0, SPACE_LG, SPACE_MD)
	style.skew = Vector2(SLANT, 0.0)
	style.shadow_offset = Vector2(4, 4)
	return style


## A repeated parallel action: OPEN this crate, BUY this pack. A paper card with an amber
## border rather than an amber block: a screen that offers three or ten instances of the SAME
## action has no single primary.
static func choice(tint: Color = AMBER) -> StyleBoxFlat:
	var style := card(SURFACE, 0, SPACE_LG, SPACE_MD)
	style.set_border_width_all(4)
	style.border_color = tint.darkened(0.15)
	style.shadow_offset = Vector2(4, 4)
	return style


## Everything that is not the primary action: paper, ink, a smaller shadow.
static func secondary(fill: Color = SURFACE) -> StyleBoxFlat:
	var style := card(fill, 0, SPACE_LG, SPACE_MD)
	style.shadow_offset = Vector2(4, 4)
	return style


## The pressed state of any of the above: the shadow gone and the card dropped into its place.
static func pressed(style: StyleBoxFlat) -> StyleBoxFlat:
	var down: StyleBoxFlat = style.duplicate()
	down.shadow_size = 0
	down.expand_margin_left = -3
	down.expand_margin_right = 3
	down.expand_margin_top = -3
	down.expand_margin_bottom = 3
	return down


## A label that sits on the dark page or over the 3D world: paper lettering with an ink edge.
## Makes `label` fit a box `width` px wide and at most `max_lines` lines tall (play-test 8: card
## text ran past its card). Wraps if it may take more than one line, then steps the font down
## until the text fits, never below `min_size`; whatever still does not fit ends in "...".
## Call after the label's text, font and size are set.
static func fit(label: Label, width: float, max_lines: int = 1, min_size: int = 11) -> Label:
	var face: Font = label.get_theme_font("font")
	var size: int = label.get_theme_font_size("font_size")
	label.custom_minimum_size.x = width
	label.size.x = width
	label.clip_text = max_lines == 1
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if max_lines > 1 else TextServer.AUTOWRAP_OFF
	label.max_lines_visible = max_lines
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	while size > min_size and lines_of(face, label.text, width, size) > max_lines:
		size -= 1
	label.add_theme_font_size_override("font_size", size)
	return label


## How many lines `text` takes at `size` in a box `width` px wide (words kept whole).
static func lines_of(face: Font, text: String, width: float, size: int) -> int:
	var total: int = 0
	for paragraph: String in text.split("\n"):
		var line: String = ""
		var count: int = 1
		for word: String in paragraph.split(" ", false):
			var trial: String = word if line.is_empty() else line + " " + word
			if face.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and not line.is_empty():
				count += 1
				line = word
			else:
				line = trial
		# A single word wider than the box is a line that does not fit at all.
		if face.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			count += 99
		total += count
	return total


static func on_page(label: Label, outline: int = 8) -> Label:
	label.add_theme_color_override("font_color", PAGE_TEXT)
	label.add_theme_color_override("font_outline_color", HAIRLINE)
	label.add_theme_constant_override("outline_size", outline)
	return label


## How far a plate leans. A slanted edge is the cheapest thing that separates a game's
## controls from an operating system's: nothing in a settings dialog leans, and a hub
## built only from level rectangles read as one.
const SLANT: float = 0.24


## A leaning plate: tabs, the primary action, the mission card.
static func slant(fill: Color, margin_x: int = SPACE_LG, margin_y: int = SPACE_MD,
		lean: float = SLANT) -> StyleBoxFlat:
	var style := plain(fill, 0, margin_x, margin_y)
	style.skew = Vector2(lean, 0.0)
	return style


const _ICON_DIR := "res://art/icons/"
static var _icons: Dictionary = {}


## A game-icons.net glyph (CC BY 3.0, credited in `art/icons/CREDITS.md`), tinted.
static func icon(name: String, size: int, tint: Color = TEXT) -> TextureRect:
	if not _icons.has(name):
		_icons[name] = load(_ICON_DIR + name + ".svg")
	var rect := TextureRect.new()
	rect.texture = _icons[name]
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	rect.modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## The page backdrop: the yard at night, a little lighter overhead. The comic's gutter:
## paper cards sit on it like panels on a dark page.
static func backdrop() -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.52, 1.0])
	gradient.colors = PackedColorArray([BG_TOP, BG, BG_GLOW])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	# Narrow: it is stretched across the screen and a wider source buys nothing but memory.
	texture.width = 4
	texture.height = 256

	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## The scrim that sits between the 3D yard and the interface.
##
## Transparent across the hero band and ramping to near-opaque below it -- the yard keeps
## its top third at full strength, and everything under it gets a floor dark enough for
## 14 px text to sit on. Warm at the transition: a grey ramp over a sodium-lit yard puts a
## band of dead haze exactly where the eye crosses from the art into the interface.
static func scrim(hero_height: int) -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 0.62, 1.0])
	gradient.colors = PackedColorArray([
		Color(BG.r, BG.g, BG.b, 0.0),
		Color(0.09, 0.07, 0.05, 0.30),
		Color(BG.r, BG.g, BG.b, 0.88),
		Color(BG.r, BG.g, BG.b, 0.96),
	])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	texture.width = 4
	texture.height = 256

	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Starts where the hero band starts, so the ramp is measured against the art rather
	# than against the whole window.
	rect.offset_top = float(hero_height) * 0.28
	return rect


## Applies the house style to a control tree.
##
## Godot's default theme is the single loudest "this is a prototype" signal an interface
## can send, and it reaches controls no call site ever touches -- scrollbar grabbers,
## tooltips, the disabled state of a button nobody styled. Setting it once at the root is
## the only way to catch all of them.
static func apply(root: Control) -> void:
	root.theme = theme()


static func theme() -> Theme:
	if _theme != null:
		return _theme

	var theme := Theme.new()
	theme.default_font = font()
	theme.default_font_size = SIZE_BODY

	# --- Button: comic lettering, ink on paper, dropping onto its shadow when pressed.
	theme.set_font("font", "Button", font_comic())
	var lean := Vector2(SLANT * 0.6, 0.0)
	var normal := secondary()
	var hover := secondary(SURFACE_HIGH)
	var down := pressed(normal)
	var disabled := secondary(SURFACE_SUNK)
	disabled.shadow_offset = Vector2(2, 2)
	for style: StyleBoxFlat in [normal, hover, down, disabled]:
		style.skew = lean
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", down)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", plain(Color(0, 0, 0, 0), 0))
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", TEXT)
	theme.set_color("font_pressed_color", "Button", TEXT)
	theme.set_color("font_focus_color", "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", TEXT_FAINT)
	theme.set_font_size("font_size", "Button", SIZE_HEADING + 2)

	# --- Panel
	theme.set_stylebox("panel", "Panel", card())
	theme.set_stylebox("panel", "PanelContainer", card())

	# --- Label
	theme.set_color("font_color", "Label", TEXT)
	theme.set_font_size("font_size", "Label", SIZE_BODY)
	theme.set_color("font_outline_color", "Label", HAIRLINE)

	# --- RichTextLabel
	theme.set_color("default_color", "RichTextLabel", TEXT)

	# --- ProgressBar: a sunk well with a flat fill, so a bar reads as a measurement.
	theme.set_stylebox("background", "ProgressBar", inset(SURFACE_SUNK, 0, 0, 0))
	theme.set_stylebox("fill", "ProgressBar", plain(AMBER, 0))
	theme.set_color("font_color", "ProgressBar", TEXT)
	theme.set_font_size("font_size", "ProgressBar", SIZE_MICRO)

	# --- Scrollbars, tooltips and separators. Nobody designs these and everybody sees them.
	theme.set_stylebox("scroll", "VScrollBar", plain(SURFACE_SUNK, 0))
	theme.set_stylebox("grabber", "VScrollBar", plain(HAIRLINE, 0))
	theme.set_stylebox("grabber_highlight", "VScrollBar", plain(EDGE_LIGHT, 0))
	theme.set_stylebox("grabber_pressed", "VScrollBar", plain(AMBER_DEEP, 0))
	theme.set_stylebox("panel", "TooltipPanel", card(SURFACE, 0, SPACE_MD, SPACE_SM))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_color("separator", "HSeparator", HAIRLINE)
	theme.set_color("separator", "VSeparator", HAIRLINE)

	_theme = theme
	return _theme
