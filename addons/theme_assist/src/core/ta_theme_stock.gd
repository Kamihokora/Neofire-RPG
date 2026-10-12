class_name TaThemeStock
extends Object

# AGENT: Extra stock Control Theme items. Called from TaThemeBuilder.make().
# INVARIANT: ItemList, Tree, TabBar, CheckButton, separators, TooltipPanel exist. Every
# box comes from TaChrome by role. PIXEL marks and arrows are drawn at art size and
# scaled up by whole pixels (_tex).
# DO NOT: Public DSL. Do not reimplement those Controls.

enum Arrow { UP, DOWN, LEFT, RIGHT }

const _Role := TaChrome.Role
const _State := TaChrome.State


static func apply(theme: Theme, look: TaTokens) -> void:
	_apply_button_likes(theme, look)
	_apply_spin_box(theme, look)
	_apply_lists(theme, look)
	_apply_separators(theme, look)
	_apply_tooltip(theme, look)
	_apply_v_slider(theme, look)
	_apply_marks(theme, look)
	_apply_scroll(theme, look)
	_apply_split(theme, look)
	_apply_window(theme, look)
	_apply_picker(theme, look)
	_apply_file_dialog(theme, look)
	_apply_inks(theme, look)
	_apply_inline_buttons(theme, look)


## Mark size: art pixels on PIXEL looks (scaled up by _tex), `hd` px on this display
## otherwise.
static func _px(look: TaTokens, hd: int) -> int:
	return TaDefaults.PIXEL_MARK if look.is_pixel() else look.px(hd)


## Art of the title mark: a framed gem (Framed's title icons), 7 x 7 art px.
const _GEM := [
	"..###..",
	".#+++#.",
	"#+*+++#",
	"#+++++#",
	"#+++++#",
	".#+++#.",
	"..###..",
]


## The title mark: a small framed gem in the accent, scaled by whole pixels.
static func title_mark(look: TaTokens) -> ImageTexture:
	var img := Image.create(_GEM[0].length(), _GEM.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var colors := {
		"#": look.color_border, "+": look.color_accent, "*": look.color_accent.lightened(0.5),
	}
	for y in _GEM.size():
		var row := String(_GEM[y])
		for x in row.length():
			if colors.has(row[x]):
				img.set_pixel(x, y, colors[row[x]])
	if not look.is_pixel():
		var k := maxi(1, roundi(look.px(TaDefaults.MARK) / float(_GEM.size())))
		img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
		return ImageTexture.create_from_image(img)
	return _tex(img, look)


## An ImageTexture of `img`, scaled up by whole pixels on PIXEL looks.
static func _tex(img: Image, look: TaTokens) -> ImageTexture:
	var s := look.art_scale()
	if s > 1:
		img.resize(img.get_width() * s, img.get_height() * s, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


static func _apply_button_likes(theme: Theme, look: TaTokens) -> void:
	for type_name in ["CheckButton", "MenuButton", "LinkButton"]:
		theme.set_color("font_color", type_name, look.color_text)
		theme.set_color("font_hover_color", type_name, look.color_text)
		theme.set_color("font_pressed_color", type_name, look.color_text)
		theme.set_color("font_disabled_color", type_name, look.color_disabled_text)
		theme.set_font_size("font_size", type_name, look.font_size)
	_apply_menu_button(theme, look)
	var page := TaThemeBuilder.panel_fill(look)
	theme.set_color(
			"font_hover_color", "LinkButton",
			TaThemeBuilder.text_or_ink(look, look.color_accent, page)
	)
	theme.set_constant("underline_spacing", "LinkButton", look.border_width)
	var px := _px(look, TaDefaults.ARROW)
	var arrow := _tex(_arrow_img(look.color_text, px, Arrow.DOWN), look)
	theme.set_icon("arrow", "OptionButton", arrow)
	theme.set_icon("arrow", "MenuButton", arrow.duplicate())
	theme.set_constant("arrow_margin", "OptionButton", look.content_margin)


## Small kit buttons made from stock Button. TaTagClose: the dismiss glyph inside a
## tag, no fill and no padding, so a dismissible tag is as tall as a plain one.
## TaReorderList arrows: drawn triangles in button ink, not "^" and "v".
static func _apply_inline_buttons(theme: Theme, look: TaTokens) -> void:
	theme.set_type_variation("TaTagClose", "Button")
	var bare := StyleBoxEmpty.new()
	bare.content_margin_left = maxi(1, look.border_width)
	bare.content_margin_right = maxi(1, look.border_width)
	for item in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		theme.set_stylebox(item, "TaTagClose", bare.duplicate())
	theme.set_stylebox("focus", "TaTagClose", TaThemeBuilder.focus_ring(look))
	var px := _px(look, TaDefaults.ARROW)
	var ink := TaThemeBuilder.ink_on(look, look.color_surface)
	theme.set_icon("move_up", "TaReorderList", _tex(_arrow_img(ink, px, Arrow.UP), look))
	theme.set_icon("move_down", "TaReorderList", _tex(_arrow_img(ink, px, Arrow.DOWN), look))


## MenuButton is flat by default: no fill is drawn, so its label sits on the page.
## Page ink, an accent hover, and a panel fill for flat = false.
static func _apply_menu_button(theme: Theme, look: TaTokens) -> void:
	var fill := TaThemeBuilder.panel_fill(look)
	TaThemeBuilder.button_boxes(
			theme, "MenuButton", look, [fill, look.color_surface_hover, look.color_bg]
	)
	var ink := TaThemeBuilder.ink_on(look, fill)
	for item in [
		"font_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"
	]:
		theme.set_color(item, "MenuButton", ink)
	theme.set_color(
			"font_hover_color", "MenuButton",
			TaThemeBuilder.text_or_ink(look, look.color_accent, fill)
	)


static func _apply_spin_box(theme: Theme, look: TaTokens) -> void:
	var px := _px(look, TaDefaults.ARROW)
	var updown := _tex(_updown_img(look.color_text, px), look)
	theme.set_icon("updown", "SpinBox", updown)
	theme.set_constant("field_and_buttons_separation", "SpinBox", look.content_margin)
	theme.set_constant("buttons_width", "SpinBox", updown.get_width())


static func _apply_lists(theme: Theme, look: TaTokens) -> void:
	var m := look.content_margin
	var panel := TaChrome.box(look, _Role.WELL, look.color_bg, look.color_border, m)
	var selected := TaChrome.box(
			look, _Role.CHIP, look.color_surface_hover, look.color_accent, m / 2
	)
	var hover := TaChrome.box(look, _Role.CHIP, look.color_surface, look.color_border, m / 2)
	theme.set_stylebox("panel", "ItemList", panel)
	theme.set_stylebox("selected", "ItemList", selected)
	theme.set_stylebox("selected_focus", "ItemList", selected.duplicate())
	theme.set_stylebox("cursor", "ItemList", TaThemeBuilder.focus_ring(look))
	theme.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	theme.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	theme.set_stylebox("hovered", "ItemList", hover)
	for item in ["hovered_selected", "hovered_selected_focus"]:
		theme.set_stylebox(item, "ItemList", selected.duplicate())
		theme.set_stylebox(item, "Tree", selected.duplicate())
	theme.set_color("font_color", "ItemList", look.color_text)
	theme.set_color("font_hovered_color", "ItemList", look.color_text)
	theme.set_color("font_selected_color", "ItemList", look.color_text)
	theme.set_font_size("font_size", "ItemList", look.font_size)
	theme.set_stylebox("panel", "Tree", panel.duplicate())
	theme.set_stylebox("selected", "Tree", selected.duplicate())
	theme.set_stylebox("selected_focus", "Tree", selected.duplicate())
	theme.set_stylebox("cursor", "Tree", TaThemeBuilder.focus_ring(look))
	theme.set_stylebox("cursor_unfocused", "Tree", StyleBoxEmpty.new())
	theme.set_stylebox("focus", "Tree", StyleBoxEmpty.new())
	theme.set_color("font_color", "Tree", look.color_text)
	theme.set_color("font_selected_color", "Tree", look.color_text)
	theme.set_font_size("font_size", "Tree", look.font_size)
	var title_btn := TaChrome.box(look, _Role.TAB, look.color_surface, look.color_border, m / 2)
	theme.set_stylebox("title_button_normal", "Tree", title_btn)
	theme.set_stylebox("title_button_hover", "Tree", title_btn.duplicate())
	theme.set_stylebox("title_button_pressed", "Tree", title_btn.duplicate())
	var px := _px(look, TaDefaults.ARROW)
	theme.set_icon("arrow", "Tree", _tex(_arrow_img(look.color_text, px, Arrow.DOWN), look))
	theme.set_icon(
			"arrow_collapsed", "Tree", _tex(_arrow_img(look.color_text, px, Arrow.RIGHT), look)
	)
	theme.set_icon(
			"arrow_collapsed_mirrored", "Tree",
			_tex(_arrow_img(look.color_text, px, Arrow.LEFT), look)
	)
	theme.set_color("relationship_line_color", "Tree", look.color_border)
	theme.set_constant("draw_relationship_lines", "Tree", 1)


static func _apply_separators(theme: Theme, look: TaTokens) -> void:
	theme.set_stylebox("separator", "HSeparator", line(look, false))
	theme.set_stylebox("separator", "VSeparator", line(look, true))
	theme.set_constant("separation", "HSeparator", maxi(1, look.border_width))
	theme.set_constant("separation", "VSeparator", maxi(1, look.border_width))


## Border-coloured rule for separators. A StyleBoxLine, because separators draw their
## box exactly as tall as its minimum size: a margin-less StyleBoxFlat drew nothing.
static func line(look: TaTokens, vertical: bool) -> StyleBoxLine:
	var rule := StyleBoxLine.new()
	rule.color = look.color_border
	rule.thickness = maxi(1, look.border_width)
	rule.vertical = vertical
	return rule


static func _apply_tooltip(theme: Theme, look: TaTokens) -> void:
	var fill := TaThemeBuilder.panel_fill(look)
	theme.set_stylebox(
			"panel", "TooltipPanel",
			TaChrome.box(look, _Role.FRAME, fill, look.color_accent, look.content_margin)
	)
	theme.set_color("font_color", "TooltipLabel", TaThemeBuilder.ink_on(look, fill))
	theme.set_font_size("font_size", "TooltipLabel", look.font_size)


## A VSlider draws its track as wide as the box's minimum width, so the side margins
## are the track width (HSlider uses top and bottom). Zero drew no track at all.
static func _apply_v_slider(theme: Theme, look: TaTokens) -> void:
	var lane := TaChrome.box(look, _Role.TRACK, look.color_bg, look.color_border, 0)
	var fill := TaChrome.box(look, _Role.FILL, look.color_accent, look.color_accent, 0)
	var width := TaThemeBuilder.track(look)
	for box in [lane, fill]:
		box.content_margin_left = width / 2
		box.content_margin_right = width - width / 2
	theme.set_stylebox("slider", "VSlider", lane)
	theme.set_stylebox("grabber_area", "VSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "VSlider", fill.duplicate())
	theme.set_stylebox("focus", "VSlider", TaThemeBuilder.focus_ring(look))


static func _apply_marks(theme: Theme, look: TaTokens) -> void:
	var px := _px(look, TaDefaults.MARK)
	# Checked must read louder than unchecked: an accent box with a contrasting tick.
	var tick := TaThemeBuilder.ink_on(look, look.color_accent)
	var on := _tex(_mark_img(look.color_accent, look.color_accent, tick, true, false, px), look)
	var off := _tex(
			_mark_img(look.color_bg, look.color_border, look.color_accent, false, false, px), look
	)
	var on_d := _tex(
			_mark_img(look.color_disabled_bg, look.color_border, look.color_muted, true, false, px),
			look
	)
	var off_d := _tex(
			_mark_img(
					look.color_disabled_bg, look.color_border, look.color_muted, false, false, px
			),
			look
	)
	var smooth := not look.is_pixel()
	var ring := 1.0 if look.is_pixel() else 2.0
	var rad_on := _tex(
			_disc_img(look.color_bg, look.color_accent, look.color_accent, true, px, ring, smooth),
			look
	)
	var rad_off := _tex(
			_disc_img(
					look.color_bg, look.color_border, look.color_bg, false, px, ring, smooth
			),
			look
	)
	var rad_on_d := _tex(
			_disc_img(
					look.color_disabled_bg, look.color_border, look.color_muted, true, px, ring,
					smooth
			),
			look
	)
	var rad_off_d := _tex(
			_disc_img(
					look.color_disabled_bg, look.color_border, look.color_disabled_bg, false, px,
					ring, smooth
			),
			look
	)
	# Every icon the two classes size from. CheckBox reserves the largest of them, so
	# the engine's 16 px radio_*_disabled left a smaller mark top-aligned in a 16 px slot.
	var icons := {
		"checked": on, "unchecked": off, "checked_disabled": on_d, "unchecked_disabled": off_d,
		"radio_checked": rad_on, "radio_unchecked": rad_off,
		"radio_checked_disabled": rad_on_d, "radio_unchecked_disabled": rad_off_d,
		"checked_mirrored": on, "unchecked_mirrored": off,
		"checked_disabled_mirrored": on_d, "unchecked_disabled_mirrored": off_d,
	}
	for type_name in ["CheckBox", "CheckButton"]:
		for item in icons:
			theme.set_icon(item, type_name, icons[item])
	# A ring thumb, larger than the track: an accent ring round a centre that reads on
	# the accent fill.
	var knob := TaDefaults.PIXEL_SLIDER_KNOB if look.is_pixel() else look.px(TaDefaults.SLIDER_KNOB)
	var core := TaThemeBuilder.ink_on(look, look.color_accent)
	var grab := _tex(_disc_img(core, look.color_accent, core, false, knob, ring, smooth), look)
	var grab_hi := _tex(
			_disc_img(core, look.color_accent, look.color_accent, true, knob, ring, smooth), look
	)
	var grab_off := _tex(
			_disc_img(
					look.color_disabled_bg, look.color_border, look.color_disabled_bg, false, knob,
					ring, smooth
			),
			look
	)
	for slider in ["HSlider", "VSlider"]:
		theme.set_icon("grabber", slider, grab)
		theme.set_icon("grabber_highlight", slider, grab_hi)
		theme.set_icon("grabber_disabled", slider, grab_off)


static func _apply_scroll(theme: Theme, look: TaTokens) -> void:
	var lane := TaChrome.box(look, _Role.TRACK, look.color_bg, look.color_border, 2)
	var grab := TaChrome.box(look, _Role.FILL, look.color_surface_hover, look.color_border, 2)
	var grab_hi := TaChrome.box(look, _Role.FILL, look.color_accent, look.color_accent, 2)
	for bar in ["HScrollBar", "VScrollBar"]:
		theme.set_stylebox("scroll", bar, lane)
		theme.set_stylebox("grabber", bar, grab)
		theme.set_stylebox("grabber_highlight", bar, grab_hi)
		theme.set_stylebox("grabber_pressed", bar, grab_hi.duplicate())
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())


static func _apply_split(theme: Theme, look: TaTokens) -> void:
	var bar := TaChrome.box(look, _Role.TRACK, look.color_surface, look.color_border, 2)
	var grab := _tex(
			_mark_img(look.color_accent, look.color_border, look.color_text, true, true, 8), look
	)
	for type_name in ["SplitContainer", "HSplitContainer", "VSplitContainer"]:
		theme.set_stylebox("split_bar_background", type_name, bar)
		theme.set_icon("grabber", type_name, grab)
		theme.set_constant("separation", type_name, look.border_width + 2)
	theme.set_icon("h_grabber", "SplitContainer", grab)
	theme.set_icon("v_grabber", "SplitContainer", grab)


static func _apply_window(theme: Theme, look: TaTokens) -> void:
	var fill := TaThemeBuilder.panel_fill(look)
	var border := TaChrome.box(look, _Role.FRAME, fill, look.color_border, look.content_margin)
	theme.set_stylebox("embedded_border", "Window", border)
	theme.set_stylebox("embedded_unfocused_border", "Window", border.duplicate())
	theme.set_color("title_color", "Window", TaThemeBuilder.ink_on(look, fill))
	theme.set_font_size("title_font_size", "Window", look.font_size)
	theme.set_constant(
			"title_height", "Window",
			TaLook.metric_for(
					look, TaDefaults.WINDOW_TITLE_HEIGHT, TaDefaults.PIXEL_WINDOW_TITLE_HEIGHT
			)
	)


static func _apply_picker(theme: Theme, look: TaTokens) -> void:
	# Outline only — Godot draws this OVER the SV square.
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.draw_center = false
	focus.border_color = look.color_accent
	focus.set_border_width_all(maxi(1, look.focus_width))
	focus.set_corner_radius_all(0 if look.is_pixel() else look.radius)
	focus.set_content_margin_all(2)
	focus.anti_aliasing = not look.is_pixel()
	theme.set_stylebox("picker_focus_rectangle", "ColorPicker", focus)
	theme.set_stylebox("picker_focus_circle", "ColorPicker", focus.duplicate())
	var cursor := _tex(
			_mark_img(look.color_accent, look.color_text, look.color_text, true, true, 8), look
	)
	theme.set_icon("picker_cursor", "ColorPicker", cursor)
	theme.set_icon("overbright_indicator", "ColorPicker", cursor)
	# The swatch fills the button's content box: the Button's text padding left a 5 px
	# strip of colour in a short row. The button's own frame, then a thin inset.
	var inset := look.art_scale() * 2 if look.is_pixel() else maxi(2, look.px(3))
	for state in theme.get_stylebox_list("Button"):
		if state != "focus":
			theme.set_stylebox(
					state, "ColorPickerButton",
					_swatch_box(theme.get_stylebox(state, "Button"), inset, look)
			)


## A Button box whose content area runs to the frame plus `inset` (the slant too).
static func _swatch_box(box: StyleBox, inset: int, look: TaTokens) -> StyleBox:
	var out := box.duplicate() as StyleBox
	var flat := box as StyleBoxFlat
	var tex := box as StyleBoxTexture
	var slant := 0.0
	if flat != null:
		slant = absf(flat.skew.x) * look.button_min_height
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		var edge := 0.0
		if flat != null:
			edge = flat.get_border_width(side)
		elif tex != null:
			edge = tex.get_texture_margin(side)
		if side == SIDE_LEFT or side == SIDE_RIGHT:
			edge += slant
		out.set_content_margin(side, minf(box.get_margin(side), edge + inset))
	return out


static func _apply_file_dialog(theme: Theme, look: TaTokens) -> void:
	var px := _px(look, TaDefaults.MARK)
	var folder := _tex(
			_mark_img(look.color_accent, look.color_border, look.color_accent, true, false, px),
			look
	)
	var file := _tex(
			_mark_img(look.color_surface, look.color_border, look.color_text, false, false, px),
			look
	)
	theme.set_icon("folder", "FileDialog", folder)
	theme.set_icon("file", "FileDialog", file)
	theme.set_icon("parent_folder", "FileDialog", folder)
	theme.set_color("folder_icon_color", "FileDialog", look.color_accent)
	theme.set_color("file_disabled_color", "FileDialog", look.color_disabled_text)


## Text colours Godot would otherwise take from its default theme (near-white),
## and inks for fills that are not the page. Each must read on what it sits on.
static func _apply_inks(theme: Theme, look: TaTokens) -> void:
	var on_surface := TaThemeBuilder.ink_on(look, look.color_surface)
	var on_selected := TaThemeBuilder.ink_on(look, look.color_surface_hover)
	for type_name in ["CheckBox", "CheckButton"]:
		# Check boxes draw no face (TaThemeBuilder), so their text sits on the page.
		for item in [
			"font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_hover_pressed_color",
		]:
			theme.set_color(item, type_name, look.color_text)
	theme.set_color("font_focus_color", "LinkButton", look.color_text)
	theme.set_color("font_placeholder_color", "LineEdit", look.color_muted)
	theme.set_color("font_selected_color", "LineEdit", look.color_text)
	theme.set_color("clear_button_color", "LineEdit", look.color_text)
	theme.set_color("clear_button_color_pressed", "LineEdit", look.color_accent)
	theme.set_color("caret_color", "TextEdit", look.color_accent)
	theme.set_color("font_placeholder_color", "TextEdit", look.color_muted)
	theme.set_color("font_readonly_color", "TextEdit", look.color_muted)
	theme.set_color("font_selected_color", "TextEdit", look.color_text)
	for item in ["font_selected_color", "font_hovered_selected_color"]:
		theme.set_color(item, "ItemList", on_selected)
	theme.set_color(
			"font_hovered_color", "ItemList", TaThemeBuilder.ink_on(look, look.color_surface)
	)
	theme.set_color("font_selected_color", "Tree", on_selected)
	theme.set_color("font_hovered_selected_color", "Tree", on_selected)
	theme.set_color("font_hovered_color", "Tree", look.color_text)
	theme.set_color("font_hovered_dimmed_color", "Tree", look.color_muted)
	theme.set_color("font_disabled_color", "Tree", look.color_disabled_text)
	theme.set_color("custom_button_font_highlight", "Tree", look.color_text)
	theme.set_color("title_button_color", "Tree", on_surface)


static func _mark_img(
		bg: Color,
		border: Color,
		fill: Color,
		on: bool,
		radio: bool,
		px: int
	) -> Image:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var inset := 1 if px >= 10 else 0
	for y in range(inset, px - inset):
		for x in range(inset, px - inset):
			var edge := (
					x == inset or y == inset or x == px - inset - 1 or y == px - inset - 1
			)
			if radio:
				var cx := (px - 1) * 0.5
				var cy := (px - 1) * 0.5
				var r := (px - 2 - inset * 2) * 0.5
				var d := Vector2(x - cx, y - cy).length()
				if d > r:
					continue
				edge = d > r - 1.0
				if edge:
					img.set_pixel(x, y, border)
				elif on and d <= r * 0.45:
					img.set_pixel(x, y, fill)
				else:
					img.set_pixel(x, y, bg)
				continue
			if edge:
				img.set_pixel(x, y, border)
			else:
				img.set_pixel(x, y, bg)
	if on and not radio:
		_stroke_check(img, fill, inset, px)
	return img


## Round mark: centre, a ring of ring_w px, and an optional dot. smooth blends the edges
## by pixel coverage (HD); Pixel keeps hard edges on the integer grid.
static func _disc_img(
		center: Color,
		ring_color: Color,
		dot: Color,
		dot_on: bool,
		px: int,
		ring_w: float,
		smooth: bool
	) -> Image:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (px - 1) * 0.5
	var r := px * 0.5 - 0.5
	var dot_r := r * 0.4
	for y in px:
		for x in px:
			var d := Vector2(x - c, y - c).length()
			var cover := clampf(r + 0.5 - d, 0.0, 1.0) if smooth else (1.0 if d <= r else 0.0)
			if cover <= 0.0:
				continue
			var col := center
			if dot_on:
				var in_dot := clampf(dot_r + 0.5 - d, 0.0, 1.0) if smooth else float(d <= dot_r)
				col = col.lerp(dot, in_dot)
			var in_ring := (
					clampf(d - (r - ring_w) + 0.5, 0.0, 1.0) if smooth else float(d > r - ring_w)
			)
			col = col.lerp(ring_color, in_ring)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * cover))
	return img


static func _stroke_check(img: Image, color: Color, inset: int, px: int) -> void:
	var x0 := inset + 1
	var y0 := int(px * 0.55)
	var x1 := int(px * 0.42)
	var y1 := px - inset - 2
	var x2 := px - inset - 2
	var y2 := inset + 1
	_stroke_line(img, x0, y0, x1, y1, color)
	_stroke_line(img, x1, y1, x2, y2, color)
	if px >= 10:
		# Two pixels thick at HD sizes; one reads as a hairline next to 16 px text.
		_stroke_line(img, x0, y0 - 1, x1, y1 - 1, color)
		_stroke_line(img, x1, y1 - 1, x2, y2 - 1, color)


static func _stroke_line(img: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var x := x0
	var y := y0
	var w := img.get_width()
	var h := img.get_height()
	while true:
		if x >= 0 and y >= 0 and x < w and y < h:
			img.set_pixel(x, y, color)
		if x == x1 and y == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy


## SpinBox up/down pair: up centred in the top half (it increments), down in the
## bottom half, with a gap so the pair does not read as one diamond.
static func _updown_img(color: Color, px: int) -> Image:
	var up := _up_triangle(color, px)
	var down := up.duplicate() as Image
	down.flip_y()
	var img := Image.create(px, px * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.blit_rect(up, Rect2i(0, 0, px, px), Vector2i.ZERO)
	img.blit_rect(down, Rect2i(0, 0, px, px), Vector2i(0, px))
	return img


## One triangle drawn pointing up, turned for the rest, so a direction cannot be
## drawn backwards (1.10 drew the dropdown and open-row arrows pointing up).
static func _arrow_img(color: Color, px: int, dir: Arrow) -> Image:
	var img := _up_triangle(color, px)
	match dir:
		Arrow.DOWN:
			img.flip_y()
		Arrow.RIGHT:
			img.rotate_90(CLOCKWISE)
		Arrow.LEFT:
			img.rotate_90(COUNTERCLOCKWISE)
	return img


## Symmetric up triangle centred in a px square (px even): rows 2, 4, 6... px wide.
## Centred, so flips and turns stay centred on the text line.
static func _up_triangle(color: Color, px: int) -> Image:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var half := int(px / 2.0)
	var top := int((px - half) / 2.0)
	for y in half:
		for x in range(half - 1 - y, half + 1 + y):
			img.set_pixel(x, top + y, color)
	return img
