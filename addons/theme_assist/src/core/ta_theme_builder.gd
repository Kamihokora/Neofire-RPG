class_name TaThemeBuilder
extends Object

# AGENT: Internal Theme factory. Maps TaTokens knobs to stock + kit types.
# INVARIANT: make() turns the look into on-screen sizes once (screen()), for this display
# (TaDisplay): VECTOR metrics times the display scale, PIXEL metrics times the art scale,
# kit pixel faces at exactly their on-screen size. Every Theme carries FIT_META, the fit
# it was made for, so TaLook.refit can rebuild it when the window changes. Every box
# comes from TaChrome by role, so Flat, Modern, Framed, and Pixel share one wiring.
# DO NOT: Call EditorPlugin. Tint a look into another. Read TaLook.active while building.

const _Crt := preload("res://addons/theme_assist/src/core/ta_crt_overlay.gd")
## Meta on every Theme make() returns: the display fit it was made for (TaDisplay.fit_key).
const FIT_META := &"ta_fit"
const _Role := TaChrome.Role
const _State := TaChrome.State
## Metric tokens that scale with the display: art pixels in the PIXEL family (times the
## art scale), px at 1080 in the VECTOR family (times the display scale).
const _SCALED := [
	"radius", "border_width", "control_border", "edge", "inset", "lip", "shadow_size",
	"accent_bar",
	"content_margin", "panel_margin", "button_min_height", "focus_width", "outline_size",
	"text_shadow", "font_size", "font_size_title", "font_size_caption", "title_tracking",
]


static func make_flat() -> Theme:
	return make(TaTokens.flat())


## A Theme for `tokens` (Flat when null), sized for this display. scale_override > 0
## replaces the art scale (a pixel framebuffer builds at 1).
static func make(tokens: TaTokens = null, scale_override: int = 0) -> Theme:
	var art := tokens if tokens != null else TaTokens.new()
	# Glass surfaces clear only as far as their text allows over any scene (D39).
	var look := screen(TaContrast.settle_glass(art), scale_override)
	var theme := Theme.new()
	theme.set_meta(FIT_META, _fit_of(look))
	_apply_fonts(theme, look)
	_apply_boxes(theme, look)
	apply_button(theme, "Button", look)
	apply_button(theme, "OptionButton", look)
	_apply_primary(theme, look)
	_apply_panel(theme, look)
	_apply_label(theme, look)
	_apply_line_edit(theme, look)
	_apply_check_box(theme, look)
	_apply_slider(theme, look)
	_apply_progress(theme, look)
	_apply_popup(theme, look)
	_apply_tabs(theme, look)
	_apply_kit_widgets(theme, look)
	TaThemeTones.apply_semantic(theme, look)
	TaThemeStock.apply(theme, look)
	var regular: Font = theme.default_font if theme.default_font != null else ThemeDB.fallback_font
	TaThemeText.apply(theme, look, regular)
	return theme


## A copy of `look` with every metric in on-screen px for this display: PIXEL metrics
## times the art scale (pixel_scale then holds it), VECTOR metrics times the display
## scale (display_px holds it; a 1 px line stays at least 1 px).
static func screen(look: TaTokens, scale_override: int = 0) -> TaTokens:
	var out := look.duplicate() as TaTokens
	if look.is_pixel():
		var s := scale_override if scale_override > 0 else TaDisplay.art_scale(look)
		out.pixel_scale = s
		for key in _SCALED:
			out.set(key, int(look.get(key)) * s)
		return out
	var k := TaDisplay.vector_scale(look)
	out.display_px = k
	for key in _SCALED:
		var hd := int(look.get(key))
		out.set(key, maxi(1, roundi(hd * k)) if hd > 0 else hd)
	return out


## The fit an on-screen look was made for, as TaDisplay.fit_key writes it.
static func _fit_of(look: TaTokens) -> String:
	if look.is_pixel():
		return "art %d" % look.pixel_scale
	return "px %.3f" % look.display_px


## Box, flow, and grid gaps on the kit grid, so every container in a kit tree spaces the
## same way and follows the display.
static func _apply_boxes(theme: Theme, look: TaTokens) -> void:
	var g := gap(look)
	for type_name in ["BoxContainer", "HBoxContainer", "VBoxContainer"]:
		theme.set_constant("separation", type_name, g)
	for type_name in [
		"GridContainer", "FlowContainer", "HFlowContainer", "VFlowContainer",
	]:
		theme.set_constant("h_separation", type_name, g)
		theme.set_constant("v_separation", type_name, g)


## Write a generated Theme to `path` (`.tres`) for Project Settings → Theme.
static func save_theme(path: String, tokens: TaTokens = null) -> Error:
	return ResourceSaver.save(make(tokens), path)


## Assign a generated Theme onto a Control tree. Safe in exported games.
## sync_display: also switch the Window to a pixel framebuffer for PIXEL looks (the
## window then does the scaling, so the Theme builds at scale 1). Off by default so a
## pixel Theme on a HUD does not resize an HD game.
static func apply_to(
		control: Control,
		tokens: TaTokens = null,
		sync_display: bool = false
	) -> Theme:
	var look := tokens if tokens != null else TaLook.current()
	var framebuffer := sync_display and look.is_pixel()
	var theme := make(look, 1 if framebuffer else 0)
	TaLook.bind(look)
	if is_instance_valid(control):
		control.theme = theme
		TaLook.track_paint(control, look)
		TaDropIn.unpaint_below(control)
		_Crt.sync_on(control, look.crt_intensity > 0.0, look.crt_intensity)
		if sync_display:
			TaDisplay.sync_from(control, look)
		TaLook.refresh_tree(control)
	return theme


static func chrome_for(
		look: TaTokens,
		role: TaChrome.Role,
		fill: Color,
		line: Color,
		margin: int,
		state: TaChrome.State = TaChrome.State.NORMAL
	) -> StyleBox:
	return TaChrome.box(look, role, fill, line, margin, state)


## Icon-to-text gap on the look's grid.
static func gap(look: TaTokens) -> int:
	if look.is_pixel():
		return TaDefaults.PIXEL_SEPARATION * look.art_scale()
	return look.px(TaDefaults.SEPARATION)


static func _apply_fonts(theme: Theme, look: TaTokens) -> void:
	theme.default_font_size = look.font_size
	var body := face_at(look.face, look.font_size)
	if body != null:
		theme.default_font = body


## `font` ready for `size` on screen: kit pixel faces are rebuilt to land 1:1.
static func face_at(font: Font, size: int) -> Font:
	if font == null:
		return null
	return TaPixelFont.at_size(font, size)


## The caption face (face_caption, else face) at the caption size, or null for default.
static func caption_face(look: TaTokens) -> Font:
	var font := look.face_caption if look.face_caption != null else look.face
	return face_at(font, look.font_size_caption)


## The caption face cut to its figures: no line air over the digits or under the
## baseline, so a slot count's plate is its digits and its margin, short enough to sit on
## the slot's top frame without reaching the row above.
static func figure_face(look: TaTokens) -> Font:
	var size := look.font_size_caption
	var face := caption_face(look)
	if face == null:
		face = ThemeDB.fallback_font
	var cap := roundi(size * TaDefaults.CAP_HEIGHT)
	var art := TaPixelFont.cap_height(face)
	if art > 0:
		cap = art * int(face.get_meta(TaPixelFont.META_SCALE, 1))
	var cut := FontVariation.new()
	cut.base_font = face
	cut.spacing_top = cap - roundi(face.get_ascent(size))
	cut.spacing_bottom = -roundi(face.get_descent(size))
	for key in [TaPixelFont.META_FACE, TaPixelFont.META_SCALE]:
		if face.has_meta(key):
			cut.set_meta(key, face.get_meta(key))
	return cut


static func apply_button(theme: Theme, type_name: String, look: TaTokens) -> void:
	button_boxes(
		theme, type_name, look,
		[look.color_surface, look.color_surface_hover, look.color_surface_pressed]
	)


## normal / hover / pressed / disabled CONTROL boxes, the focus ring, and inks. `fills`
## is [normal, hover, pressed]. Hover and press take the accent line on VECTOR looks.
static func button_boxes(
		theme: Theme,
		type_name: String,
		look: TaTokens,
		fills: Array,
		line: Color = Color(0, 0, 0, 0)
	) -> void:
	var m := look.content_margin
	var edge := look.color_border if line.a <= 0.0 else line
	var hot := edge if look.is_pixel() else look.color_accent
	var normal: Color = fills[0]
	var hover: Color = fills[1]
	var pressed: Color = fills[2]
	theme.set_stylebox("normal", type_name, TaChrome.box(look, _Role.CONTROL, normal, edge, m))
	theme.set_stylebox(
			"hover", type_name, TaChrome.box(look, _Role.CONTROL, hover, hot, m, _State.HOVER)
	)
	var down := TaChrome.box(look, _Role.CONTROL, pressed, hot, m, _State.PRESSED)
	theme.set_stylebox("pressed", type_name, down)
	theme.set_stylebox("hover_pressed", type_name, down.duplicate())
	theme.set_stylebox(
			"disabled", type_name,
			TaChrome.box(look, _Role.CONTROL, look.color_disabled_bg, edge, m, _State.DISABLED)
	)
	theme.set_stylebox("focus", type_name, TaChrome.ring(look, true))
	var ink := _ink_on(look, normal)
	theme.set_color("font_color", type_name, ink)
	theme.set_color("font_focus_color", type_name, ink)
	theme.set_color("font_hover_color", type_name, _ink_on(look, hover))
	theme.set_color("font_pressed_color", type_name, _ink_on(look, pressed))
	theme.set_color("font_hover_pressed_color", type_name, _ink_on(look, pressed))
	theme.set_color("font_disabled_color", type_name, look.color_disabled_text)
	theme.set_color("icon_normal_color", type_name, ink)
	theme.set_font_size("font_size", type_name, look.font_size)
	theme.set_constant("h_separation", type_name, gap(look))


## TaPrimary: the accent button (confirm, the main call to action).
static func _apply_primary(theme: Theme, look: TaTokens) -> void:
	theme.set_type_variation("TaPrimary", "Button")
	var a := look.color_accent
	var hover := a.lightened(0.12)
	var pressed := a.darkened(0.18)
	button_boxes(theme, "TaPrimary", look, [a, hover, pressed], a.darkened(0.45))


## Theme on this node or the nearest ancestor. Skips the per-control theme
## cache, which can latch a fallback color before the node enters the tree.
## Only that one Theme: a kit type set higher up is not found (see theme_with_color).
static func nearest_theme(node: Node) -> Theme:
	var current := node
	while current != null:
		if current is Control and (current as Control).theme != null:
			return (current as Control).theme
		current = current.get_parent()
	return null


## The nearest Theme above `node` (itself first) that defines colour `item` for
## `type_name`, then the project Theme; null if none. As in Godot's own lookup, a
## game panel's Theme without the item does not hide the kit's (1.12.1 badges took
## body text on their warning fill there). No control cache, so it works off-tree.
static func theme_with_color(node: Node, item: StringName, type_name: StringName) -> Theme:
	var current := node
	while current != null:
		var theme: Theme = null
		if current is Control:
			theme = (current as Control).theme
		elif current is Window:
			theme = (current as Window).theme
		if theme != null and theme.has_color(item, type_name):
			return theme
		current = current.get_parent()
	var project := ThemeDB.get_project_theme()
	if project != null and project.has_color(item, type_name):
		return project
	return null


## Copy a kit type's text items (ink, face, size, shadow) onto `label`. Chips and toasts
## draw text in a child Label, which does not see its parent's type variation.
static func paint_label(label: Label, source: Theme, type_name: StringName) -> void:
	label.add_theme_color_override("font_color", source.get_color("font_color", type_name))
	if source.has_font("font", type_name):
		label.add_theme_font_override("font", source.get_font("font", type_name))
	if source.has_font_size("font_size", type_name):
		var size := source.get_font_size("font_size", type_name)
		if size > 0:
			label.add_theme_font_size_override("font_size", size)
	if source.has_color("font_shadow_color", type_name):
		var shade := source.get_color("font_shadow_color", type_name)
		label.add_theme_color_override("font_shadow_color", shade)


## The text shadow for `ink`: the look's shadow under light ink, none under dark ink
## (a dark shadow under dark text on a bright chip smears the letters).
static func shadow_for(look: TaTokens, ink: Color) -> Color:
	if look.text_shadow <= 0 or TaContrast.luminance(ink) < 0.3:
		return Color(0, 0, 0, 0)
	return Color(look.color_shadow, 1.0)


## `color` as text on `fill` when it reads there (over any scene, for glass); else ink.
static func text_or_ink(look: TaTokens, color: Color, fill: Color) -> Color:
	if TaContrast.worst(color, fill) >= TaDefaults.MIN_TEXT_CONTRAST:
		return color
	return _ink_on(look, fill)


static func _ink_on(look: TaTokens, fill: Color) -> Color:
	return TaContrast.ink_on(look, fill)


## Fill for kit panels, popups, and tooltips (TaContrast.panel_fill: the panel color
## when text reads on it, else moved toward the page; glass keeps its alpha if it can).
static func panel_fill(look: TaTokens) -> Color:
	return TaContrast.panel_fill(look)


## Outline-only focus for stock controls in seam files (TaThemeStock).
static func focus_ring(look: TaTokens, slanted: bool = false) -> StyleBox:
	return TaChrome.ring(look, slanted)


## Text or page colour, whichever reads on `fill`. For seam files (TaThemeTones).
static func ink_on(look: TaTokens, fill: Color) -> Color:
	return _ink_on(look, fill)


## WCAG contrast ratio of two colours. For seam files (TaThemeTones).
static func contrast(a: Color, b: Color) -> float:
	return TaContrast.ratio(a, b)


## A framed panel style for `type_name` (FRAME role, panel fill, panel margin).
static func frame(look: TaTokens, fill: Color = Color(0, 0, 0, 0)) -> StyleBox:
	var f := fill if fill.a > 0.0 else panel_fill(look)
	return TaChrome.box(look, _Role.FRAME, f, look.color_border, look.panel_margin)


static func _apply_panel(theme: Theme, look: TaTokens) -> void:
	var panel := frame(look)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel.duplicate())


static func _apply_label(theme: Theme, look: TaTokens) -> void:
	theme.set_color("font_color", "Label", look.color_text)
	theme.set_font_size("font_size", "Label", look.font_size)
	if look.text_shadow > 0:
		theme.set_color("font_shadow_color", "Label", Color(look.color_shadow, 1.0))
		theme.set_constant("shadow_offset_x", "Label", look.text_shadow)
		theme.set_constant("shadow_offset_y", "Label", look.text_shadow)
	else:
		theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	theme.set_type_variation("TaTitle", "Label")
	theme.set_font_size("font_size", "TaTitle", look.font_size_title)
	theme.set_color("font_color", "TaTitle", look.color_text)
	var title := _title_face(look)
	if title != null:
		theme.set_font("font", "TaTitle", title)
	theme.set_type_variation("TaCaption", "Label")
	theme.set_font_size("font_size", "TaCaption", look.font_size_caption)
	theme.set_color("font_color", "TaCaption", look.color_muted)
	var caption := caption_face(look)
	if caption != null:
		theme.set_font("font", "TaCaption", caption)
	theme.set_constant("outline_size", "Label", look.outline_size)
	if look.outline_size > 0:
		theme.set_color("font_outline_color", "Label", Color(look.color_shadow, 0.85))
	theme.set_color("default_color", "RichTextLabel", look.color_text)
	theme.set_font_size("normal_font_size", "RichTextLabel", look.font_size)


## The title face (face_title, else face) at the title size, tracked when
## title_tracking > 0.
static func _title_face(look: TaTokens) -> Font:
	var font := look.face_title if look.face_title != null else look.face
	var base := face_at(font, look.font_size_title)
	if look.title_tracking <= 0:
		return base
	var tracked := FontVariation.new()
	tracked.base_font = base if base != null else ThemeDB.fallback_font
	tracked.spacing_glyph = look.title_tracking
	return tracked


static func _apply_line_edit(theme: Theme, look: TaTokens) -> void:
	var m := look.content_margin
	for type_name in ["LineEdit", "TextEdit"]:
		theme.set_stylebox(
				"normal", type_name,
				TaChrome.box(look, _Role.WELL, look.color_bg, look.color_border, m)
		)
		theme.set_stylebox(
				"focus", type_name,
				TaChrome.box(look, _Role.WELL, look.color_bg, look.color_accent, m, _State.HOVER)
		)
		theme.set_stylebox(
				"read_only", type_name,
				TaChrome.box(look, _Role.WELL, look.color_disabled_bg, look.color_border, m)
		)
		theme.set_color("font_color", type_name, look.color_text)
		theme.set_font_size("font_size", type_name, look.font_size)
	theme.set_color("font_uneditable_color", "LineEdit", look.color_muted)
	theme.set_color("caret_color", "LineEdit", look.color_accent)


static func _apply_check_box(theme: Theme, look: TaTokens) -> void:
	theme.set_color("font_color", "CheckBox", look.color_text)
	theme.set_color("font_hover_color", "CheckBox", look.color_text)
	theme.set_color("font_pressed_color", "CheckBox", look.color_text)
	theme.set_color("font_disabled_color", "CheckBox", look.color_disabled_text)
	theme.set_font_size("font_size", "CheckBox", look.font_size)
	theme.set_constant("h_separation", "CheckBox", gap(look))
	# Check boxes are lines of text with a mark, not buttons: no face, no lip.
	var bare := StyleBoxEmpty.new()
	bare.set_content_margin_all(look.content_margin / 2)
	for item in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		theme.set_stylebox(item, "CheckBox", bare.duplicate())
		theme.set_stylebox(item, "CheckButton", bare.duplicate())
	theme.set_stylebox("focus", "CheckBox", focus_ring(look))
	theme.set_stylebox("focus", "CheckButton", focus_ring(look))


## Track height for sliders on this look.
static func track(look: TaTokens) -> int:
	if look.is_pixel():
		return TaDefaults.PIXEL_SLIDER_TRACK_HEIGHT * look.art_scale()
	return look.px(TaDefaults.SLIDER_TRACK_HEIGHT)


static func _apply_slider(theme: Theme, look: TaTokens) -> void:
	var lane := TaChrome.box(look, _Role.TRACK, look.color_bg, look.color_border, 0)
	lane.content_margin_top = track(look) / 2
	lane.content_margin_bottom = track(look) - track(look) / 2
	var fill := TaChrome.box(look, _Role.FILL, look.color_accent, look.color_accent, 0)
	fill.content_margin_top = lane.content_margin_top
	fill.content_margin_bottom = lane.content_margin_bottom
	theme.set_stylebox("slider", "HSlider", lane)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill.duplicate())
	theme.set_stylebox("focus", "HSlider", focus_ring(look))


static func _apply_progress(theme: Theme, look: TaTokens) -> void:
	var pad := maxi(2, look.border_width + 1)
	theme.set_stylebox(
			"background", "ProgressBar",
			TaChrome.box(look, _Role.TRACK, look.color_bg, look.color_border, pad)
	)
	theme.set_stylebox(
			"fill", "ProgressBar",
			TaChrome.box(look, _Role.FILL, look.color_accent, look.color_accent, pad)
	)
	# The percentage straddles fill and track; TaBar splits its ink at the fill edge.
	# A plain ProgressBar draws ink picked for the fill, outlined in ink picked for the
	# track, so one of the two reads wherever a digit lands.
	theme.set_color("font_color", "ProgressBar", _ink_on(look, look.color_accent))
	theme.set_color("font_outline_color", "ProgressBar", _ink_on(look, look.color_bg))
	theme.set_constant("outline_size", "ProgressBar", maxi(2, look.outline_size))
	theme.set_font_size("font_size", "ProgressBar", look.font_size)


static func _apply_popup(theme: Theme, look: TaTokens) -> void:
	var fill := panel_fill(look)
	var panel := TaChrome.box(look, _Role.FRAME, fill, look.color_border, look.content_margin)
	var hover := TaChrome.box(
			look, _Role.CHIP, look.color_surface_hover, look.color_accent, look.content_margin / 2
	)
	# A line, not a margin-less box: PopupMenu draws its separator as tall as its minimum.
	var sep := TaThemeStock.line(look, false)
	theme.set_stylebox("panel", "PopupMenu", panel)
	theme.set_stylebox("hover", "PopupMenu", hover)
	theme.set_stylebox("hover_pressed", "PopupMenu", hover.duplicate())
	theme.set_stylebox("separator", "PopupMenu", sep)
	theme.set_stylebox("labeled_separator_left", "PopupMenu", sep.duplicate())
	theme.set_stylebox("labeled_separator_right", "PopupMenu", sep.duplicate())
	theme.set_stylebox("panel", "PopupPanel", panel.duplicate())
	theme.set_stylebox("panel", "AcceptDialog", panel.duplicate())
	theme.set_stylebox("panel", "ConfirmationDialog", panel.duplicate())
	theme.set_color("font_color", "PopupMenu", _ink_on(look, fill))
	theme.set_color("font_hover_color", "PopupMenu", _ink_on(look, look.color_surface_hover))
	theme.set_color("font_accelerator_color", "PopupMenu", look.color_muted)
	theme.set_color("font_disabled_color", "PopupMenu", look.color_disabled_text)
	theme.set_color("font_separator_color", "PopupMenu", look.color_muted)
	theme.set_font_size("font_size", "PopupMenu", look.font_size)


static func _apply_tabs(theme: Theme, look: TaTokens) -> void:
	var m := look.content_margin
	var fill := panel_fill(look)
	# Pixel pages and panels are close in tone, so idle pixel tabs take the button fill.
	var idle := look.color_surface if look.is_pixel() else look.color_bg
	var off := TaChrome.box(look, _Role.TAB, idle, look.color_border, m)
	# Pixel looks: the selected tab is the coloured one (a plain underline read backwards
	# next to coloured idle tabs). Vector looks: the selected tab joins the panel.
	var picked := look.color_accent if look.is_pixel() else fill
	var on := TaChrome.box(look, _Role.TAB, picked, look.color_accent, m)
	var hot := TaChrome.box(look, _Role.TAB, look.color_surface_hover, look.color_border, m)
	for type_name in ["TabContainer", "TabBar"]:
		theme.set_stylebox("tab_unselected", type_name, off.duplicate())
		theme.set_stylebox("tab_hovered", type_name, hot.duplicate())
		theme.set_stylebox("tab_selected", type_name, on.duplicate())
		theme.set_stylebox("tab_disabled", type_name, off.duplicate())
		theme.set_stylebox("tab_focus", type_name, focus_ring(look, true))
		# Idle tabs speak quietly (muted ink, where it reads); the selected tab takes full ink
		# on the panel fill, so selection reads without decoration.
		var idle_ink := text_or_ink(look, look.color_muted, idle)
		theme.set_color("font_unselected_color", type_name, idle_ink)
		theme.set_color("font_hovered_color", type_name, _ink_on(look, look.color_surface_hover))
		theme.set_color("font_selected_color", type_name, _ink_on(look, picked))
		theme.set_color("font_disabled_color", type_name, look.color_disabled_text)
		theme.set_font_size("font_size", type_name, look.font_size)
	# One frame line per window: a tab page inside a window, inside a column panel, drew
	# the same 1 px line three deep (Flat read as an admin tool). A vector page is the
	# panel fill with no line, one surface with its window; a pixel page sinks into a well
	# of the page colour, so framed windows stand on it (borderless Pixel panels vanished
	# on a page of their own fill).
	var page := TaChrome.box(look, _Role.CARD, fill, look.color_border, look.panel_margin)
	if look.is_pixel():
		page = TaChrome.box(look, _Role.WELL, look.color_bg, look.color_border, look.panel_margin)
	theme.set_stylebox("panel", "TabContainer", page)
	theme.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())


static func _kit_panel(
		theme: Theme,
		type_name: String,
		base_class: String,
		look: TaTokens,
		role: TaChrome.Role,
		fill: Color,
		margin: int,
		line: Color = Color(0, 0, 0, 0)
	) -> void:
	theme.set_type_variation(type_name, base_class)
	var edge := line if line.a > 0.0 else look.color_border
	theme.set_stylebox("panel", type_name, TaChrome.box(look, role, fill, edge, margin))


## Fill of cards inside a panel (color_card): chips, bars, dials, shop cards, toasts.
static func card_fill(look: TaTokens) -> Color:
	return look.color_card


## Text on a card: TaCardText (ink that reads on color_card) and TaCardCaption (muted
## where it reads there, else ink; the caption face and size). Card components use them,
## so Framed's cream cards carry dark ink and every other look keeps its own.
static func _apply_card_text(theme: Theme, look: TaTokens, card: Color) -> void:
	var ink := _ink_on(look, card)
	theme.set_type_variation("TaCardText", "Label")
	theme.set_color("font_color", "TaCardText", ink)
	theme.set_color("font_shadow_color", "TaCardText", shadow_for(look, ink))
	theme.set_type_variation("TaCardCaption", "Label")
	var quiet := text_or_ink(look, look.color_muted, card)
	theme.set_color("font_color", "TaCardCaption", quiet)
	theme.set_color("font_shadow_color", "TaCardCaption", shadow_for(look, quiet))
	theme.set_font_size("font_size", "TaCardCaption", look.font_size_caption)
	var caption := caption_face(look)
	if caption != null:
		theme.set_font("font", "TaCardCaption", caption)


## Text drawn straight onto the game world (an interact hint, a floating number), in the
## subtitle rule: light ink with a dark halo in every look, so it reads over a night or a
## snow scene. The light one of text and page is the ink, the dark one the halo (Modern's
## dark ink vanished over a night scene; dark ink in a light halo read as hollow letters).
## Vector looks outline; bitmap faces cannot, so pixel looks drop a solid shadow.
static func _apply_scene_text(theme: Theme, look: TaTokens) -> void:
	var light := look.color_text
	var dark := look.color_bg
	if TaContrast.luminance(light) < TaContrast.luminance(dark):
		light = look.color_bg
		dark = look.color_text
	var halo := Color(look.color_shadow if look.is_pixel() else dark, 1.0)
	var specs := {"TaSceneText": light, "TaSceneSuccess": _scene_ink(look.color_success, halo)}
	for type_name in specs:
		theme.set_type_variation(type_name, "Label")
		theme.set_color("font_color", type_name, Color(specs[type_name], 1.0))
		if look.is_pixel():
			var drop := maxi(1, look.art_scale())
			theme.set_color("font_shadow_color", type_name, halo)
			theme.set_constant("shadow_offset_x", type_name, drop)
			theme.set_constant("shadow_offset_y", type_name, drop)
		else:
			theme.set_color("font_outline_color", type_name, halo)
			theme.set_constant("outline_size", type_name, maxi(2, look.px(3)))


## A tone lifted toward white until it reads at 4.5:1 on the scene-text halo.
static func _scene_ink(tone: Color, halo: Color) -> Color:
	var ink := tone
	for i in 8:
		if TaContrast.ratio(ink, halo) >= 4.5:
			break
		ink = ink.lightened(0.2)
	return ink


## Badge and tag padding on this look.
static func badge_margin(look: TaTokens) -> int:
	if look.is_pixel():
		return TaDefaults.PIXEL_BADGE_MARGIN * look.art_scale()
	return look.px(TaDefaults.BADGE_MARGIN)


static func _apply_kit_widgets(theme: Theme, look: TaTokens) -> void:
	var s := panel_fill(look)
	var p := look.panel_margin
	var c := look.content_margin
	var bm := badge_margin(look)
	var frame_role := _Role.FRAME
	var chip := _Role.CHIP
	for type_name in [
		"TaModal", "TaItemTooltip", "TaPopover", "TaWindow", "TaHeaderPanel", "TaSortList",
		"TaReorderList", "TaMinimap", "TaSpeechBubble", "TaChoicePicker", "TaWinSplash",
		"TaBanner", "TaQuestTracker", "TaScoreboard", "TaInspector", "TaTabWindow",
	]:
		_kit_panel(theme, type_name, "PanelContainer", look, frame_role, s, p)
# Cards that live inside a panel (a shop shelf, a party list, a reel), on color_card
	# (Framed's cream): their text takes TaCardText / TaCardCaption ink.
	var card := card_fill(look)
	for type_name in ["TaShopCard", "TaHighlightCell", "TaPartyFrame", "TaCompass"]:
		_kit_panel(theme, type_name, "PanelContainer", look, _Role.CARD, card, p)
	# Toasts speak the button language (Modern: slant, lip, cut corners).
	for type_name in ["TaToast", "TaToastMuted"]:
		_kit_panel(theme, type_name, "PanelContainer", look, _Role.NOTE, card, p)
	_kit_panel(theme, "TaDialog", "PopupPanel", look, frame_role, s, p)
	_kit_panel(theme, "TaInfoPopup", "PopupPanel", look, frame_role, s, p)
	# HUD atoms and cards sit inside panels: a card, not a second frame.
	for type_name in ["TaChip", "TaBar", "TaVBar", "TaRadial"]:
		_kit_panel(theme, type_name, "PanelContainer", look, _Role.CARD, card, c)
	_apply_card_text(theme, look, card)
	_apply_scene_text(theme, look)
	var header := look.color_accent if look.accent_bar > 0 else look.color_border
	for type_name in ["TaWindowTitleBar", "TaHeaderBar"]:
		_kit_panel(theme, type_name, "PanelContainer", look, _Role.HEADER, s, c, header)
		if look.title_mark:
			theme.set_icon("mark", type_name, TaThemeStock.title_mark(look))
	# Modal and dialog titles: the same accent rule as panel headers, nothing without one.
	var rule: StyleBox = StyleBoxEmpty.new()
	if look.accent_bar > 0:
		var line := StyleBoxFlat.new()
		line.draw_center = false
		line.anti_aliasing = false
		line.border_color = look.color_accent
		line.border_width_bottom = look.accent_bar
		line.content_margin_bottom = look.accent_bar + gap(look)
		rule = line
	theme.set_type_variation("TaDialogHeader", "PanelContainer")
	theme.set_stylebox("panel", "TaDialogHeader", rule)
	_kit_panel(theme, "TaBadge", "PanelContainer", look, chip, look.color_surface, bm)
	_kit_panel(theme, "TaBadgeMuted", "PanelContainer", look, chip, look.color_bg, bm)
	_kit_panel(theme, "TaTag", "PanelContainer", look, chip, look.color_surface, bm)
	_kit_panel(theme, "TaTagMuted", "PanelContainer", look, chip, look.color_bg, bm)
	_kit_panel(theme, "TaKeycap", "PanelContainer", look, _Role.CONTROL, look.color_surface, bm)
	theme.set_type_variation("TaSlot", "Button")
	_apply_slot(theme, look)
	theme.set_type_variation("TaInfoIcon", "Button")
	apply_button(theme, "TaInfoIcon", look)
	for spec in [
		["TaButtonRow", "HBoxContainer"], ["TaButtonCol", "VBoxContainer"],
		["TaToggleGroup", "HBoxContainer"], ["TaFieldRow", "HBoxContainer"],
		["TaInteractHint", "HBoxContainer"], ["TaKillFeed", "VBoxContainer"],
		["TaHotbar", "HBoxContainer"], ["TaStatRow", "HBoxContainer"],
		["TaReticle", "Control"], ["TaVignette", "Control"],
		["TaBuffStrip", "HBoxContainer"], ["TaStepper", "HBoxContainer"],
		["TaIconGrid", "GridContainer"], ["TaSlotGrid", "GridContainer"],
	]:
		theme.set_type_variation(spec[0], spec[1])
	TaThemeTones.apply_builtin(theme, look)
	_apply_chip_inks(theme, look, card)


## Item slots: a framed well; hover and select take the accent line.
static func _apply_slot(theme: Theme, look: TaTokens) -> void:
	var m := look.content_margin
	var well := look.color_bg
	var hot := look.color_accent
	var slot := _Role.SLOT
	theme.set_stylebox("normal", "TaSlot", TaChrome.box(look, slot, well, look.color_border, m))
	theme.set_stylebox(
			"hover", "TaSlot",
			TaChrome.box(look, slot, look.color_surface_hover, hot, m, _State.HOVER)
	)
	# Pressed is also the selected slot (TaSlot.selected).
	var down := TaChrome.box(look, slot, look.color_surface_pressed, hot, m, _State.PRESSED)
	theme.set_stylebox("pressed", "TaSlot", down)
	theme.set_stylebox("hover_pressed", "TaSlot", down.duplicate())
	theme.set_stylebox(
			"disabled", "TaSlot",
			TaChrome.box(look, slot, look.color_disabled_bg, look.color_border, m)
	)
	theme.set_stylebox("focus", "TaSlot", focus_ring(look))
	var ink := _ink_on(look, well)
	for item in ["font_color", "font_hover_color", "font_focus_color"]:
		theme.set_color(item, "TaSlot", ink)
	theme.set_color("font_pressed_color", "TaSlot", _ink_on(look, look.color_surface_pressed))
	theme.set_color("font_disabled_color", "TaSlot", look.color_disabled_text)
	theme.set_font_size("font_size", "TaSlot", look.font_size)


static func _apply_chip_inks(theme: Theme, look: TaTokens, panel: Color) -> void:
	# Badges and tags use the look's caption (size and face), like every small label.
	var badge_fs := look.font_size_caption
	var badge_face := face_at(
			look.face_caption if look.face_caption != null else look.face, badge_fs
	)
	var tones := {
		"": look.color_surface, "Accent": look.color_accent, "Muted": look.color_bg,
		"Danger": look.color_danger, "Success": look.color_success,
		"Warning": look.color_warning, "Rarity": look.color_rarity, "Count": look.color_text,
	}
	for prefix in ["TaBadge", "TaTag"]:
		for tone in tones:
			var type_name: String = prefix + String(tone)
			theme.set_font_size("font_size", type_name, badge_fs)
			if badge_face != null:
				theme.set_font("font", type_name, badge_face)
			var ink := look.color_muted if tone == "Muted" else _ink_on(look, tones[tone])
			theme.set_color("font_color", type_name, ink)
			theme.set_color("font_shadow_color", type_name, shadow_for(look, ink))
	theme.set_font("font", "TaBadgeCount", figure_face(look))
	theme.set_color("font_color", "TaToast", _ink_on(look, panel))
	theme.set_color("font_color", "TaToastAccent", _ink_on(look, look.color_accent))
	theme.set_color("font_color", "TaToastMuted", text_or_ink(look, look.color_muted, panel))
	theme.set_color("font_color", "TaToastDanger", _ink_on(look, look.color_danger))
	theme.set_color("font_color", "TaToastSuccess", _ink_on(look, look.color_success))
	theme.set_color("font_color", "TaToastWarning", _ink_on(look, look.color_warning))
	theme.set_color("font_color", "TaShopCardOn", _ink_on(look, look.color_accent))
	for toast in [
		"TaToast", "TaToastAccent", "TaToastMuted", "TaToastDanger", "TaToastSuccess",
		"TaToastWarning",
	]:
		var ink := theme.get_color("font_color", toast)
		theme.set_color("font_shadow_color", toast, shadow_for(look, ink))


## Theme type for a named tone: tone_type("TaTag", "money") -> "TaTagMoney".
static func tone_type(prefix: String, tone_name: String) -> String:
	return prefix + tone_name.to_pascal_case()
