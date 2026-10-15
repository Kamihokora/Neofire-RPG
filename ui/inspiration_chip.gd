extends Button

signal picked(id: String)
const BORDER := preload("res://ui/inspiration_border.gdshader")
var word_id := ""
var _paper: ShaderMaterial


func configure(id: String, title: String, count: int, story: bool) -> void:
	word_id = id
	size = Vector2(280, 92)
	focus_mode = Control.FOCUS_NONE
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var face := ColorRect.new()
	face.size = size
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper = ShaderMaterial.new()
	_paper.shader = BORDER
	_paper.set_shader_parameter(&"paper", Color("15151b") if story else Color("fffdf7"))
	face.material = _paper
	add_child(face)
	var label := Label.new()
	label.text = title
	label.position = Vector2(16, 8)
	label.size = Vector2(248, 76)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", 24)
	label.add_theme_color_override(&"font_color", Color.WHITE if story else Color("15151b"))
	add_child(label)
	if not story:
		var badge := Panel.new()
		badge.position = Vector2(239, -10)
		badge.size = Vector2(55, 36)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color("ff4263")
		style.border_color = Color.WHITE
		style.set_border_width_all(2)
		style.set_corner_radius_all(15)
		badge.add_theme_stylebox_override(&"panel", style)
		add_child(badge)
		var quantity := Label.new()
		quantity.text = str(count)
		quantity.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quantity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		quantity.add_theme_font_size_override(&"font_size", 21)
		quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(quantity)
	tooltip_text = "剧情灵感 · 只能使用一次" if story else "普通灵感 · 剩余%d" % count
	pressed.connect(func() -> void: picked.emit(word_id))


func set_chosen(value: bool) -> void:
	_paper.set_shader_parameter(&"selected", value)


func set_invalid(value: bool) -> void:
	_paper.set_shader_parameter(&"invalid_pair", value)
