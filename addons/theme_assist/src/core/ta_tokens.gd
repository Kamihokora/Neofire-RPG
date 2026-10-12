@tool
class_name TaTokens
extends Resource

# AGENT: Look knobs as a Resource. One kit, four presets: Flat, Modern, Framed, Pixel
# (TaDefaults.FLAT / MODERN / FRAMED / PIXEL). The Playground saves one of these.
# INVARIANT: TaTokens.new() is Flat, field for field (flat() == new()). schema_version 3.
# VECTOR draws StyleBoxFlat; PIXEL draws generated integer chrome, metrics in art pixels
# (pixel_scale screen pixels each).
# DO NOT: Public Theme DSL. Add a fifth preset. Put behavior (input, sound) here.

## The bundled faces (SIL OFL, fonts/OFL.txt). Loaded, never preloaded: on a project's
## first import scripts compile before the fonts are imported, and a failed preload broke
## every kit script.
const FONT_DIR := "res://addons/theme_assist/fonts/"
const _FLAT_BODY := "BarlowSemiCondensed-Medium.ttf"
const _FLAT_TITLE := "BarlowSemiCondensed-SemiBold.ttf"
const _MODERN_BODY := "Barlow-Medium.ttf"
const _MODERN_TITLE := "Barlow-Bold.ttf"

enum Family {
	## StyleBoxFlat chrome, smooth edges. Flat and Modern.
	VECTOR,
	## Generated pixel chrome on an integer grid. Framed and Pixel.
	PIXEL,
}

@export var schema_version: int = 3
## The preset this set started from: flat, modern, framed, or pixel. Informational;
## the builder reads the knobs, never the id.
@export var look_id: String = TaDefaults.FLAT["look_id"]
@export var family: Family = TaDefaults.FLAT["family"]
## Size of the whole UI, every preset: 1 is the look as drawn for a 1080 px tall canvas.
## The kit multiplies it by the display (TaDisplay), so set density once and the UI
## tracks the window from a Steam Deck to 4K.
@export_range(0.5, 3.0, 0.05) var ui_scale: float = TaDefaults.FLAT["ui_scale"]

@export_group("Colors")
## Page: full-screen backgrounds, fields, tracks.
@export var color_bg: Color = TaDefaults.FLAT["color_bg"]
## Panels, cards, windows, popups, tooltips.
@export var color_panel: Color = TaDefaults.FLAT["color_panel"]
## Cards inside a panel: chips, bars, dials, shop cards, toasts. The panel color on Flat
## and Modern; Framed's cream; Pixel's inner slab. Their text takes ink that reads on it.
@export var color_card: Color = TaDefaults.FLAT["color_card"]
## Buttons, tabs, and other things you press.
@export var color_surface: Color = TaDefaults.FLAT["color_surface"]
@export var color_surface_hover: Color = TaDefaults.FLAT["color_surface_hover"]
@export var color_surface_pressed: Color = TaDefaults.FLAT["color_surface_pressed"]
## Ink: body text. Text on fills is picked from ink and page so it reads (4.5:1).
@export var color_text: Color = TaDefaults.FLAT["color_text"]
@export var color_muted: Color = TaDefaults.FLAT["color_muted"]
## Focus, selection, fills, the primary button.
@export var color_accent: Color = TaDefaults.FLAT["color_accent"]
@export var color_border: Color = TaDefaults.FLAT["color_border"]
## Pixel edges, inset lines, drop shadows, the text shadow.
@export var color_shadow: Color = TaDefaults.FLAT["color_shadow"]
@export var color_danger: Color = TaDefaults.FLAT["color_danger"]
@export var color_success: Color = TaDefaults.FLAT["color_success"]
@export var color_warning: Color = TaDefaults.FLAT["color_warning"]
## Rare items and special tags. Its own hue, never the warning colour.
@export var color_rarity: Color = TaDefaults.FLAT["color_rarity"]
@export var color_disabled_bg: Color = TaDefaults.FLAT["color_disabled_bg"]
@export var color_disabled_text: Color = TaDefaults.FLAT["color_disabled_text"]
## Extra named tones. {"money": Color(...)} paints TaTag / TaBadge / TaToast
## tone_name "money" next to the built-in danger, success, warning, rarity.
@export var tones: Dictionary = {}

@export_group("Type")
## Body face. Flat wears Barlow Semi Condensed, Modern Barlow (both SIL OFL, in fonts/);
## the pixel looks wear the kit's bitmap faces (TaPixelFont). Null is Godot's default.
@export var face: Font
## Title face (TaTitle, window and dialog titles). Null uses face.
@export var face_title: Font
## Caption face (TaCaption, badges, small labels). Null uses face.
@export var face_caption: Font
## Real bold face for RichTextLabel [b] and TaBold. Null derives one from face.
@export var face_bold: Font
## Real italic face for RichTextLabel [i] and TaItalic. Null keeps text upright:
## a FontVariation slant renders straight stems upright in 4.7, so we never fake it.
@export var face_italic: Font
## Fonts tried, in order, for glyphs the face lacks (emoji, CJK). Applied to every face
## the builder sets, pixel faces included. Web exports have no system fonts.
@export var fallback_fonts: Array[Font] = []
@export var font_size: int = TaDefaults.FLAT["font_size"]
@export var font_size_title: int = TaDefaults.FLAT["font_size_title"]
@export var font_size_caption: int = TaDefaults.FLAT["font_size_caption"]
## Extra px between title letters.
@export var title_tracking: int = TaDefaults.FLAT["title_tracking"]
@export var outline_size: int = TaDefaults.FLAT["outline_size"]
## Px a text shadow (color_shadow) sits below and right of labels. 0 is none.
@export var text_shadow: int = TaDefaults.FLAT["text_shadow"]

@export_group("Chrome")
## Corner size. PIXEL looks cut it in steps, each row half the one before (4: 4, 2, 1).
@export var radius: int = TaDefaults.FLAT["radius"]
## Cut corners instead of round ones (VECTOR).
@export var chamfer: bool = TaDefaults.FLAT["chamfer"]
## Border of frames: panels, windows, dialogs, popups, tooltips.
@export var border_width: int = TaDefaults.FLAT["border_width"]
## Border of what sits inside a frame: buttons, fields, tracks, slots, tags, tabs. 0 tells
## them apart by fill alone, so lines never nest (Flat, Modern).
@export var control_border: int = TaDefaults.FLAT["control_border"]
## Dark outline outside the border (color_shadow). PIXEL frames and buttons.
@export var edge: int = TaDefaults.FLAT["edge"]
## Dark line inside a frame's border (PIXEL panels).
@export var inset: int = TaDefaults.FLAT["inset"]
## Pressable depth: a darker band under buttons that a press collapses. 0 is flat.
@export var lip: int = TaDefaults.FLAT["lip"]
## Drop shadow under panels and buttons. 0 is none (Flat, Modern default).
@export var shadow_size: int = TaDefaults.FLAT["shadow_size"]
## Slant of buttons, tabs, and chips (VECTOR), as a fraction of their height.
@export var skew: float = TaDefaults.FLAT["skew"]
## Accent stripe under header bars and window titles, px. 0 is none.
@export var accent_bar: int = TaDefaults.FLAT["accent_bar"]
## Tags and badges end in a notched ribbon (PIXEL family; Framed).
@export var chip_ribbon: bool = TaDefaults.FLAT["chip_ribbon"]
## Selection and focus are corner brackets in the accent, not a ring (PIXEL family;
## Framed), so a selected slot does not wear the same border as an empty one.
@export var select_brackets: bool = TaDefaults.FLAT["select_brackets"]
## Windows and header panels show a small framed mark before the title (Framed).
@export var title_mark: bool = TaDefaults.FLAT["title_mark"]
@export var content_margin: int = TaDefaults.FLAT["content_margin"]
## Padding inside panels, windows, and dialogs.
@export var panel_margin: int = TaDefaults.FLAT["panel_margin"]
@export var button_min_height: int = TaDefaults.FLAT["button_min_height"]
@export var focus_width: int = TaDefaults.FLAT["focus_width"]
## PIXEL: screen pixels per art pixel on a 1080 px tall canvas (2 = each art pixel is a
## 2 x 2 block). The kit rounds it with the display: Pixel 3 is 2 on a Steam Deck and 6
## at 4K. Always a whole number, so pixel chrome stays on the pixel grid.
@export_range(1, 6) var pixel_scale: int = TaDefaults.FLAT["pixel_scale"]

@export_group("Motion")
@export var motion_hover_scale: float = TaDefaults.FLAT["motion_hover_scale"]
@export var motion_press_scale: float = TaDefaults.FLAT["motion_press_scale"]
## Degrees a hovered button leans (the Pixel wobble). 0 is none.
@export var motion_hover_tilt: float = TaDefaults.FLAT["motion_hover_tilt"]
@export var motion_hover_seconds: float = TaDefaults.MOTION_HOVER_SECONDS
@export var motion_press_seconds: float = TaDefaults.MOTION_PRESS_SECONDS
@export var motion_open_seconds: float = TaDefaults.MOTION_OPEN_SECONDS
@export var motion_roll_seconds: float = TaDefaults.MOTION_ROLL_SECONDS
## How loud punches, shakes, and fanfare are. 1 is the kit default.
@export var fanfare: float = TaDefaults.FLAT["fanfare"]

@export_group("Feedback")
@export var toast_seconds: float = TaDefaults.TOAST_DURATION_SECONDS
@export var dimmer_alpha: float = TaDefaults.DIMMER_COLOR.a
## Backdrop blur behind TaDimmer, in px. 0 is a plain veil.
@export var dimmer_blur: float = TaDefaults.DIMMER_BLUR
## Scanline overlay strength. An effect you can turn on, not any preset's look.
@export var crt_intensity: float = 0.0


## Runtime, never saved: the px multiplier TaThemeBuilder.screen() gave this on-screen
## copy (VECTOR looks). 1 on a look as authored.
var display_px: float = 1.0


## Flat's faces, so TaTokens.new() is Flat. A saved look sets its own over these.
func _init() -> void:
	face = bundled_font(_FLAT_BODY)
	face_title = bundled_font(_FLAT_TITLE)
	face_bold = bundled_font(_FLAT_TITLE)


## A font from the addon's fonts/ folder; null until the project has imported it.
static func bundled_font(file: String) -> Font:
	var path := FONT_DIR + file
	return load(path) as Font if ResourceLoader.exists(path) else null


func is_pixel() -> bool:
	return family == Family.PIXEL


## Screen pixels per art pixel: pixel_scale for the PIXEL family, else 1. On a look as
## authored this is pixel_scale at the 1080 px reference; TaDisplay.art_scale(look) is the
## scale on this display, and the on-screen copy (TaThemeBuilder.screen) carries it here.
func art_scale() -> int:
	return maxi(1, pixel_scale) if is_pixel() else 1


## An HD size in px on this on-screen copy (display_px applied).
func px(hd: float) -> int:
	return roundi(hd * display_px)


## A preset by id (flat, modern, framed, pixel). Unknown ids give Flat. Sizes are as
## drawn for a 1080 px tall canvas; the kit fits them to the display when it builds.
static func preset(id: String) -> TaTokens:
	var tokens := TaTokens.new()
	var data: Dictionary = TaDefaults.FLAT
	match id:
		"modern":
			data = TaDefaults.MODERN
		"framed", "terpene":  # "terpene": load alias for looks saved before the rename
			data = TaDefaults.FRAMED
		"pixel":
			data = TaDefaults.PIXEL
	for key in data:
		tokens.set(key, data[key])
	# Flat's faces are the export defaults. Modern is the same family, wider and heavier,
	# so the ladder holds together; its decoration is the chrome, not a genre face.
	match tokens.look_id:
		"modern":
			tokens.face = bundled_font(_MODERN_BODY)
			tokens.face_title = bundled_font(_MODERN_TITLE)
			tokens.face_bold = bundled_font(_MODERN_TITLE)
		"framed":
			tokens.face = TaPixelFont.face(TaPixelFont.GRAIN)
			tokens.face_title = TaPixelFont.face(TaPixelFont.GRAIN)
			tokens.face_caption = TaPixelFont.face(TaPixelFont.GRAIN_SMALL)
			tokens.face_bold = TaPixelFont.face(TaPixelFont.CHUNK)
		"pixel":
			tokens.face = TaPixelFont.face(TaPixelFont.TALL)
			tokens.face_title = TaPixelFont.face(TaPixelFont.TALL)
			tokens.face_caption = TaPixelFont.face(TaPixelFont.GRAIN_SMALL)
			tokens.face_bold = null
	return tokens


## The factory default. The same values as TaTokens.new().
static func flat() -> TaTokens:
	return preset("flat")


static func modern() -> TaTokens:
	return preset("modern")


static func framed() -> TaTokens:
	return preset("framed")


static func pixel() -> TaTokens:
	return preset("pixel")
