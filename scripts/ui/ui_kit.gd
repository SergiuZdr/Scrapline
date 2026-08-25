class_name UIKit
extends RefCounted

## The one place Scrapline's interface is described.
##
## Both the hub and the in-battle HUD build their controls from here, because two screens
## that style themselves independently drift apart on exactly the details a player reads
## as polish: corner radius, hairline colour, how far a pressed button moves, what "dim
## text" means this week.
##
## The palette is the battlefield's palette carried indoors. The signature accent is
## SODIUM AMBER -- the same colour as the yard lamp lighting the fight -- so the menus and
## the game look like one product rather than a UI bolted onto a renderer.
##
## Colour is used as a signal, not as decoration:
##
##   AMBER   the primary action on a screen. One per screen, or it stops meaning anything.
##   BLUE    information and the player's own team.
##   GREEN   confirmation, gains, things already earned.
##   RED     danger, costs, losses.
##   GOLD    premium currency, and nothing else.

# --- Surfaces ----------------------------------------------------------------
const BG := Color("0d0f14")          ## The page behind everything.
const SURFACE := Color("161a22")     ## A card sitting on the page.
const SURFACE_HIGH := Color("1e242e") ## A card sitting on a card, or a hover state.
const SURFACE_SUNK := Color("0a0c11") ## Wells: progress tracks, input fields.
const HAIRLINE := Color("2b3441")    ## Borders. Never a full-strength line.
const EDGE_LIGHT := Color("3a4759")  ## Top edge of a raised card -- fakes a light source.

# --- Ink ---------------------------------------------------------------------
const TEXT := Color("e8ecf2")
const TEXT_DIM := Color("8794a8")
const TEXT_FAINT := Color("5b6678")

# --- Signals -----------------------------------------------------------------
const AMBER := Color("f0a848")       ## Primary action. The sodium lamp.
const AMBER_DEEP := Color("c1832f")
const BLUE := Color("5aa9e6")
const GREEN := Color("5ec27a")
const RED := Color("e0664c")
const GOLD := Color("e8b73f")

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
const SIZE_DISPLAY: int = 32
const SIZE_TITLE: int = 21
const SIZE_HEADING: int = 17
const SIZE_BODY: int = 15
const SIZE_LABEL: int = 13
const SIZE_MICRO: int = 11

# --- Shape -------------------------------------------------------------------
const RADIUS_CARD: int = 12
const RADIUS_CONTROL: int = 9
const RADIUS_PILL: int = 999

## Cached so a screen rebuild does not allocate a font per label.
static var _font: SystemFont
static var _theme: Theme


## The interface font.
##
## A SystemFont stack rather than a bundled file: shipping a typeface means shipping its
## licence, and that is the user's call to make, not a decision to smuggle into a commit.
## The stack is ordered so every target platform lands on a humanist grotesque, and the
## final entry is one Godot always resolves.
static func font() -> SystemFont:
	if _font != null:
		return _font
	_font = SystemFont.new()
	_font.font_names = PackedStringArray([
		"Inter", "SF Pro Text", "Helvetica Neue", "Segoe UI Variable",
		"Segoe UI", "Roboto", "Noto Sans", "DejaVu Sans"])
	# Hinting off and subpixel positioning on: at these sizes hinting snaps stems to the
	# pixel grid and the result reads as a system dialog, which is the exact impression
	# a game menu is trying not to give.
	_font.hinting = TextServer.HINTING_NONE
	_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_ONE_HALF
	return _font


## A card: the default surface for a group of related things.
##
## The top border is lighter than the other three. That single asymmetry is what reads as
## "lit from above" and is most of the difference between a flat rectangle and a physical
## panel -- far cheaper than a gradient and it survives any background behind it.
static func card(fill: Color = SURFACE, radius: int = RADIUS_CARD,
		margin_x: int = SPACE_LG, margin_y: int = SPACE_MD) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_width_top = 1
	style.border_color = HAIRLINE
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	style.anti_aliasing = true
	return style


## A card with no shadow, for surfaces already inside another card. Nested shadows stack
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


## The primary action. Amber fill, dark ink -- the only high-chroma block on a screen, so
## the eye lands on it before it lands on anything else.
static func primary(fill: Color = AMBER) -> StyleBoxFlat:
	var style := plain(fill, RADIUS_CONTROL, SPACE_LG, SPACE_MD)
	style.border_width_bottom = 2
	style.border_color = fill.darkened(0.32)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	return style


## Everything that is not the primary action.
static func secondary(fill: Color = SURFACE_HIGH) -> StyleBoxFlat:
	var style := plain(fill, RADIUS_CONTROL, SPACE_LG, SPACE_MD)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = HAIRLINE
	return style


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
	theme.set_stylebox("normal", "Button", secondary())
	theme.set_stylebox("hover", "Button", secondary(SURFACE_HIGH.lightened(0.06)))
	var pressed := secondary(SURFACE_HIGH.darkened(0.18))
	# Pressed states lose the top hairline, so the control reads as pushed INTO the page.
	pressed.border_width_top = 0
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", plain(SURFACE.darkened(0.3), RADIUS_CONTROL,
		SPACE_LG, SPACE_MD))
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
	theme.set_stylebox("background", "ProgressBar", plain(SURFACE_SUNK, 4))
	theme.set_stylebox("fill", "ProgressBar", plain(AMBER, 4))
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

	_theme = theme
	return _theme
