extends ScrollContainer

# AGENT: Live TaTokens lab. Grouped knobs, an Affects hint, face pickers.
# INVARIANT: bind() writes every editable knob; edits emit tokens_changed. Every knob
# here is a TaTokens field, so Save (in the playground bar) keeps all of it.
# DO NOT: Save from here (the playground owns Save). Add a knob that is not a token.

const _Map := preload("res://addons/theme_assist/playground/playground_token_map.gd")
const _UI := preload("res://addons/theme_assist/playground/playground_ui.gd")
## Face picker rows: label and source. "" is none (Godot's default, or the body face for
## title and caption), "res://" a bundled font file, "kit:" a TaPixelFont face.
const _FONTS := "res://addons/theme_assist/fonts/"
const _FACE_ROWS := [
	["None", ""],
	["Barlow Semi Condensed", _FONTS + "BarlowSemiCondensed-Medium.ttf"],
	["Barlow Semi Cond. SemiBold", _FONTS + "BarlowSemiCondensed-SemiBold.ttf"],
	["Barlow", _FONTS + "Barlow-Medium.ttf"],
	["Barlow Bold", _FONTS + "Barlow-Bold.ttf"],
	["Grain (pixel)", "kit:grain"],
	["Grain Small (pixel)", "kit:grain_small"],
	["Chunk (pixel)", "kit:chunk"],
]
## The face tokens the pickers edit, in the order they show.
const _FACE_KEYS := [
	["Face", "face"], ["Title face", "face_title"], ["Caption face", "face_caption"],
	["Bold face", "face_bold"],
]

signal tokens_changed

var _look: TaTokens
var _silent: bool = false
var _col: VBoxContainer
var _affects: Label
## Face key -> its OptionButton.
var _pickers: Dictionary = {}


func _ready() -> void:
	name = "Tokens"
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	custom_minimum_size.x = _UI.ui(300)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_col = VBoxContainer.new()
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_col)
	_build()
	if _look != null:
		bind(_look)


## Panel width on this display (TaLook.refresh_tree calls this after a refit).
func refresh_metrics() -> void:
	custom_minimum_size.x = _UI.ui(300)


func bind(look: TaTokens) -> void:
	_look = look
	_silent = true
	if is_instance_valid(_col):
		_sync()
	_silent = false


func _build() -> void:
	var title := Label.new()
	title.text = "Your look"
	title.theme_type_variation = "TaTitle"
	_col.add_child(title)
	var hint := Label.new()
	hint.text = "Changes apply live. Save writes it into your project."
	hint.theme_type_variation = "TaCaption"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_col.add_child(hint)
	_affects = Label.new()
	_affects.name = "TokenAffects"
	_affects.text = "Affects: the whole Theme"
	_affects.theme_type_variation = "TaCaption"
	_affects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_col.add_child(_affects)
	var look := _section("Look", true)
	_float_row(look, "UI scale", "ui_scale", 0.5, 3.0, 0.05)
	for spec in [
		["Accent", "color_accent"], ["Surface", "color_surface"], ["Panel", "color_panel"],
		["Page", "color_bg"], ["Ink", "color_text"],
	]:
		_color_row(look, String(spec[0]), String(spec[1]))
	var colors := _section("Colors", false)
	for spec in [
		["Card", "color_card"], ["Rarity", "color_rarity"],
		["Muted", "color_muted"], ["Border", "color_border"], ["Shadow", "color_shadow"],
		["Hover", "color_surface_hover"], ["Pressed", "color_surface_pressed"],
		["Danger", "color_danger"], ["Success", "color_success"], ["Warning", "color_warning"],
		["Disabled bg", "color_disabled_bg"], ["Disabled text", "color_disabled_text"],
	]:
		_color_row(colors, String(spec[0]), String(spec[1]))
	var typ := _section("Type", false)
	_face_pickers(typ)
	_int_row(typ, "Title size", "font_size_title", 6, 96)
	_int_row(typ, "Body size", "font_size", 6, 48)
	_int_row(typ, "Caption size", "font_size_caption", 5, 32)
	_int_row(typ, "Title tracking", "title_tracking", 0, 12)
	_int_row(typ, "Text shadow", "text_shadow", 0, 4)
	_int_row(typ, "Outline", "outline_size", 0, 8)
	var chrome := _section("Chrome", false)
	_family_row(chrome)
	_int_row(chrome, "Pixel scale", "pixel_scale", 1, 6)
	_int_row(chrome, "Radius", "radius", 0, 24)
	_bool_row(chrome, "Cut corners", "chamfer")
	_int_row(chrome, "Border", "border_width", 0, 8)
	_int_row(chrome, "Control border", "control_border", 0, 8)
	_int_row(chrome, "Edge", "edge", 0, 4)
	_int_row(chrome, "Inset", "inset", 0, 4)
	_int_row(chrome, "Lip", "lip", 0, 8)
	_int_row(chrome, "Shadow", "shadow_size", 0, 16)
	_float_row(chrome, "Skew", "skew", -0.5, 0.5, 0.01)
	_int_row(chrome, "Accent bar", "accent_bar", 0, 12)
	_bool_row(chrome, "Ribbon tags", "chip_ribbon")
	_bool_row(chrome, "Select brackets", "select_brackets")
	_bool_row(chrome, "Title mark", "title_mark")
	_int_row(chrome, "Margin", "content_margin", 0, 32)
	_int_row(chrome, "Panel margin", "panel_margin", 0, 48)
	_int_row(chrome, "Button H", "button_min_height", 8, 80)
	_int_row(chrome, "Focus", "focus_width", 0, 12)
	var motion := _section("Motion", false)
	_float_row(motion, "Hover scale", "motion_hover_scale", 1.0, 1.2, 0.01)
	_float_row(motion, "Press scale", "motion_press_scale", 0.8, 1.0, 0.01)
	_float_row(motion, "Hover tilt", "motion_hover_tilt", 0.0, 8.0, 0.5)
	_float_row(motion, "Fanfare", "fanfare", 0.0, 2.0, 0.1)
	_float_row(motion, "Hover s", "motion_hover_seconds", 0.0, 0.6, 0.01)
	_float_row(motion, "Press s", "motion_press_seconds", 0.0, 0.4, 0.01)
	_float_row(motion, "Open s", "motion_open_seconds", 0.0, 0.8, 0.01)
	_float_row(motion, "Roll s", "motion_roll_seconds", 0.0, 1.2, 0.05)
	var feed := _section("Feedback", false)
	_float_row(feed, "Toast s", "toast_seconds", 0.5, 8.0, 0.1)
	_float_row(feed, "Dimmer", "dimmer_alpha", 0.0, 1.0, 0.05)
	_float_row(feed, "Blur px", "dimmer_blur", 0.0, 12.0, 0.5)
	_float_row(feed, "Scanlines", "crt_intensity", 0.0, 1.0, 0.05)


func _section(title: String, open: bool) -> GridContainer:
	var head := Button.new()
	head.toggle_mode = true
	head.button_pressed = open
	head.text = title
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var grid := GridContainer.new()
	grid.columns = 2
	grid.visible = open
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.toggled.connect(func(on: bool) -> void: grid.visible = on)
	_col.add_child(head)
	_col.add_child(grid)
	return grid


func _face_pickers(grid: GridContainer) -> void:
	for spec in _FACE_KEYS:
		var key := String(spec[1])
		grid.add_child(_label(String(spec[0]), key))
		var pick := OptionButton.new()
		pick.name = "FontPicker" if key == "face" else key.to_pascal_case() + "Picker"
		for row in _FACE_ROWS:
			pick.add_item(String(row[0]))
		# A face of your own (set in the Inspector) shows here, not as one of the rows.
		pick.add_item("Your font")
		pick.set_item_disabled(_FACE_ROWS.size(), true)
		pick.item_selected.connect(func(i: int) -> void: _on_face(key, i))
		grid.add_child(pick)
		_pickers[key] = pick


func _family_row(grid: GridContainer) -> void:
	grid.add_child(_label("Family", "family"))
	var pick := OptionButton.new()
	pick.name = "FamilyPicker"
	pick.add_item("Vector")
	pick.add_item("Pixel")
	pick.set_meta("token_key", "family")
	pick.set_meta("token_kind", "enum")
	pick.item_selected.connect(func(i: int) -> void: _set_value("family", i))
	grid.add_child(pick)


func _color_row(grid: GridContainer, caption: String, key: String) -> void:
	grid.add_child(_label(caption, key))
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(_UI.ui(64), _UI.ui(24))
	picker.set_meta("token_key", key)
	picker.set_meta("token_kind", "color")
	picker.color_changed.connect(func(c: Color) -> void: _set_value(key, c))
	grid.add_child(picker)


func _bool_row(grid: GridContainer, caption: String, key: String) -> void:
	grid.add_child(_label(caption, key))
	var box := CheckBox.new()
	box.set_meta("token_key", key)
	box.set_meta("token_kind", "bool")
	box.toggled.connect(func(on: bool) -> void: _set_value(key, on))
	grid.add_child(box)


func _int_row(grid: GridContainer, caption: String, key: String, mn: int, mx: int) -> void:
	grid.add_child(_label(caption, key))
	var box := SpinBox.new()
	box.min_value = mn
	box.max_value = mx
	box.step = 1
	box.rounded = true
	box.set_meta("token_key", key)
	box.set_meta("token_kind", "int")
	box.value_changed.connect(func(v: float) -> void: _set_value(key, int(v)))
	grid.add_child(box)


func _float_row(
		grid: GridContainer,
		caption: String,
		key: String,
		mn: float,
		mx: float,
		step: float
	) -> void:
	grid.add_child(_label(caption, key))
	var box := SpinBox.new()
	box.min_value = mn
	box.max_value = mx
	box.step = step
	box.set_meta("token_key", key)
	box.set_meta("token_kind", "float")
	box.value_changed.connect(func(v: float) -> void: _set_value(key, v))
	grid.add_child(box)


func _label(caption: String, key: String = "") -> Label:
	var label := Label.new()
	label.text = caption
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not key.is_empty():
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.mouse_entered.connect(func() -> void: _show_affects(key))
	return label


func _set_value(key: String, value: Variant) -> void:
	if _silent or _look == null:
		return
	_look.set(key, value)
	_show_affects(key)
	tokens_changed.emit()


func _show_affects(key: String) -> void:
	if is_instance_valid(_affects):
		_affects.text = _Map.affects(key)


func _on_face(key: String, index: int) -> void:
	if _silent or _look == null or index >= _FACE_ROWS.size():
		return
	_look.set(key, _font_of(String(_FACE_ROWS[index][1])))
	_show_affects(key)
	tokens_changed.emit()


static func _font_of(source: String) -> Font:
	if source.is_empty():
		return null
	if source.begins_with("kit:"):
		return TaPixelFont.face(source.substr(4))
	return load(source) as Font


## The picker row showing `font`: its kit id or its file; "Your font" for anything else.
static func _row_for(font: Font) -> int:
	if font == null:
		return 0
	var id := TaPixelFont.kit_id(font)
	for i in _FACE_ROWS.size():
		var source := String(_FACE_ROWS[i][1])
		if not id.is_empty() and source == "kit:" + id:
			return i
		if id.is_empty() and source == font.resource_path:
			return i
	return _FACE_ROWS.size()


func _sync() -> void:
	if _look == null or not is_instance_valid(_col):
		return
	_sync_node(_col)
	for key in _pickers:
		(_pickers[key] as OptionButton).select(_row_for(_look.get(key) as Font))


func _sync_node(node: Node) -> void:
	if node.has_meta("token_key"):
		var key := String(node.get_meta("token_key"))
		var kind := String(node.get_meta("token_kind"))
		var current: Variant = _look.get(key)
		if kind == "color" and node is ColorPickerButton:
			(node as ColorPickerButton).color = current as Color
		elif kind == "bool" and node is CheckBox:
			(node as CheckBox).set_pressed_no_signal(bool(current))
		elif kind == "enum" and node is OptionButton:
			(node as OptionButton).select(int(current))
		elif node is SpinBox:
			(node as SpinBox).set_value_no_signal(float(current))
	for child in node.get_children():
		_sync_node(child)
