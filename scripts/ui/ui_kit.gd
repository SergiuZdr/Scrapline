class_name UIKit
extends RefCounted

## The one place Scrapline's interface is described.
##
## Both the hub and the in-battle HUD build their controls from here, because two screens
## that style themselves independently drift apart on exactly the details a player reads
## as polish: corner radius, hairline colour, how far a pressed button moves, what "dim
## text" means this week.
##
## The palette is the reference sheets' MATERIAL list carried indoors (see
## `art/reference/STYLE.md`), not a UI palette with the yard's name on it. The earlier
## navy-and-amber set was the default look of a dark dashboard, and it read as one: nothing
## in it came from a scrapyard. Now every surface is a material the machines are made of --
## dark steel plates, dirty aluminium for anything bright, construction-yellow paint for
## the one thing to press.
##
## Colour is used as a signal, not as decoration:
##
##   AMBER   construction yellow: the primary action on a screen. One per screen.
##   BLUE    the visor light: information and the player's own team.
##   GREEN   olive livery: confirmation, gains, things already earned.
##   RED     oxide red: danger, costs, losses.
##   GOLD    copper: premium currency, and nothing else.

# --- Surfaces ----------------------------------------------------------------
#
# Dark steel, warm rather than blue. The range is still spent upward, on the plates: there
# is very little room below the page before a surface turns pure black.
const BG := Color("0d0c0a")          ## The page behind everything: tar.
const BG_TOP := Color("111317")      ## Backdrop, overhead: smog.
const BG_GLOW := Color("1d1712")     ## Backdrop, underfoot: sodium spill off the yard.
const SURFACE := Color("1b1a17")     ## A plate sitting on the page.
const SURFACE_HIGH := Color("28261f") ## A plate on a plate, or a hover state.
const SURFACE_SUNK := Color("080807") ## Wells: progress tracks, input fields.
const HAIRLINE := Color("3a362d")    ## Plate edges. Never a full-strength line.
const EDGE_LIGHT := Color("5c564a")  ## A lit edge.

# --- Ink ---------------------------------------------------------------------
const TEXT := Color("e6e1d5")        ## Dirty aluminium: the one light value.
const TEXT_DIM := Color("9d9788")    ## Primer grey.
const TEXT_FAINT := Color("676152")

# --- Signals -----------------------------------------------------------------
const AMBER := Color("e5b33d")       ## Primary action. Construction yellow.
const AMBER_DEEP := Color("b88a25")
const BLUE := Color("62b3de")
const GREEN := Color("98ae58")
const RED := Color("cf5638")
const GOLD := Color("d68b52")

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


## The display face: Big Shoulders Stencil, the lettering sprayed on a container.
##
## Used with restraint -- the wordmark, screen titles and group names. Set any smaller
## than a heading the stencil breaks read as noise, so body text never uses it.
static func font_display() -> Font:
	if _font_display == null:
		var face := FontVariation.new()
		face.base_font = _load("BigShouldersStencilDisplay.ttf")
		# Keyed by the numeric tag, not the string: a "wght" string key is accepted
		# silently and ignored, and the face falls back to its thinnest master.
		face.variation_opentype = {_tag("wght"): 800}
		_font_display = face
	return _font_display


## Readouts: tabular figures, so a number that ticks up does not shuffle the row.
static func font_numbers() -> Font:
	if _font_numbers == null:
		var face := FontVariation.new()
		face.base_font = _load("BarlowSemiCondensed-Medium.ttf")
		face.opentype_features = {_tag("tnum"): 1}
		_font_numbers = face
	return _font_numbers


static func _tag(name: String) -> int:
	return TextServerManager.get_primary_interface().name_to_tag(name)


static func _load(file: String) -> FontFile:
	var face: FontFile = load(_FONT_DIR + file) as FontFile
	# Hinting off and subpixel positioning on: at these sizes hinting snaps stems to the
	# pixel grid and the result reads as a system dialog.
	face.hinting = TextServer.HINTING_NONE
	face.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_ONE_HALF
	return face


## A plate: the default surface for a group of related things.
static func card(fill: Color = SURFACE, radius: int = RADIUS_CARD,
		margin_x: int = SPACE_LG, margin_y: int = SPACE_MD) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	style.set_border_width_all(1)
	style.border_color = HAIRLINE
	# Tight and dark: a plate bolted to the page, not a card floating over it.
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	style.anti_aliasing = true
	return style


## A plate with no shadow, for surfaces already inside another plate. Nested shadows stack
## into mud.
static func inset(fill: Color = SURFACE_HIGH, radius: int = RADIUS_CONTROL,
		margin_x: int = SPACE_MD, margin_y: int = SPACE_SM) -> StyleBoxFlat:
	var style := card(fill, radius, margin_x, margin_y)
	style.shadow_size = 0
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


## The primary action. Yellow paint, dark ink -- the only high-chroma block on a screen, so
## the eye lands on it before it lands on anything else. The darker bottom lip is what
## makes it read as a thing that goes down when pressed.
static func primary(fill: Color = AMBER) -> StyleBoxFlat:
	var style := plain(fill, RADIUS_CONTROL, SPACE_LG, SPACE_MD)
	style.skew = Vector2(SLANT, 0.0)
	style.border_width_bottom = 3
	style.border_color = fill.darkened(0.38)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	return style


## A repeated parallel action: OPEN this crate, BUY this pack.
##
## Yellow outline on a dark fill rather than a yellow block. A screen that offers three
## or ten instances of the SAME action has no single primary -- and painting each of them
## yellow puts the screen's loudest colour on every row at once.
static func choice(tint: Color = AMBER) -> StyleBoxFlat:
	var style := plain(SURFACE_HIGH, RADIUS_CONTROL, SPACE_LG, SPACE_MD)
	style.set_border_width_all(1)
	style.border_color = tint.darkened(0.10)
	return style


## Everything that is not the primary action.
static func secondary(fill: Color = SURFACE_HIGH) -> StyleBoxFlat:
	var style := plain(fill, RADIUS_CONTROL, SPACE_LG, SPACE_MD)
	style.set_border_width_all(1)
	style.border_color = HAIRLINE
	return style


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


## The page backdrop: smog overhead grading to sodium spill at the floor.
##
## Deliberately very low contrast. It has to give the page a floor and a ceiling without
## ever competing with a plate sitting on it.
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

	# --- Button
	theme.set_font("font", "Button", font_strong())
	# Every button leans a little less than a tab does, so the whole interface shares the
	# one angle without every control shouting it.
	var lean := Vector2(SLANT * 0.6, 0.0)
	var normal := secondary()
	var hover := secondary(SURFACE_HIGH.lightened(0.06))
	var pressed := secondary(SURFACE_HIGH.darkened(0.18))
	# Pressed states lose the top edge, so the control reads as pushed INTO the page.
	pressed.border_width_top = 0
	var disabled := plain(SURFACE.darkened(0.3), RADIUS_CONTROL, SPACE_LG, SPACE_MD)
	for style: StyleBoxFlat in [normal, hover, pressed, disabled]:
		style.skew = lean
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", plain(Color(0, 0, 0, 0), RADIUS_CONTROL))
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", AMBER)
	theme.set_color("font_disabled_color", "Button", TEXT_FAINT)
	theme.set_font_size("font_size", "Button", SIZE_BODY)

	# --- Panel
	theme.set_stylebox("panel", "Panel", card())
	theme.set_stylebox("panel", "PanelContainer", card())

	# --- Label
	theme.set_color("font_color", "Label", TEXT)
	theme.set_font_size("font_size", "Label", SIZE_BODY)

	# --- ProgressBar: a sunk track with a flat fill, so a bar reads as a measurement
	# rather than as another button.
	theme.set_stylebox("background", "ProgressBar", plain(SURFACE_SUNK, 1))
	theme.set_stylebox("fill", "ProgressBar", plain(AMBER, 1))
	theme.set_color("font_color", "ProgressBar", TEXT_DIM)
	theme.set_font_size("font_size", "ProgressBar", SIZE_MICRO)

	# --- Scrollbars, tooltips and separators. Nobody designs these and everybody sees
	# them.
	theme.set_stylebox("scroll", "VScrollBar", plain(SURFACE_SUNK, RADIUS_PILL))
	theme.set_stylebox("grabber", "VScrollBar", plain(HAIRLINE, RADIUS_PILL))
	theme.set_stylebox("grabber_highlight", "VScrollBar", plain(EDGE_LIGHT, RADIUS_PILL))
	theme.set_stylebox("grabber_pressed", "VScrollBar", plain(AMBER_DEEP, RADIUS_PILL))
	theme.set_stylebox("panel", "TooltipPanel", card(SURFACE_HIGH, RADIUS_CONTROL))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_color("separator", "HSeparator", HAIRLINE)
	theme.set_color("separator", "VSeparator", HAIRLINE)

	_theme = theme
	return _theme
