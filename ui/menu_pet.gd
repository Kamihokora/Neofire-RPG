extends Control
## 菜单中的角色点击接口；走动与点击弹跳分开，移动不会改变按钮本身的命中区域。

signal interacted(member_id: String, thinking: bool)

const DEFOCUS := preload("res://ui/pet_defocus.gdshader")

var member_id := ""
var thinking := false
## 相对点击区域的头顶锚点；替换小人素材后调整这里即可。
var thought_anchor := Vector2(68, 32)
var lane_width := 230.0
## 仅调整每次散步前的等待；0冻结走动，点击弹跳和思考仍可用。
var walk_frequency := 0.5:
	set(value):
		walk_frequency = clampf(value, 0, 2)
		if is_zero_approx(walk_frequency):
			_walking = false
var defocus := 0.0:
	set(value):
		defocus = value
		if _body != null:
			(_body.material as ShaderMaterial).set_shader_parameter(&"blur_amount", value)
var _body: TextureRect
var _bubble: Panel
var _button: Button
var _x := 0.0
var _direction := 1.0
var _time := 0.0
var _wait := 0.0
var _walking := false
var _bounce := 0.0
var _rng := RandomNumberGenerator.new()


func setup(id: String, art: String, width: float = 230) -> void:
	member_id = id
	lane_width = width
	custom_minimum_size = Vector2(width, 200)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	_x = width * 0.5 - 64
	_wait = _rng.randf_range(0.3, 1.4)
	_direction = -1 if _rng.randf() > 0.5 else 1
	_button = Button.new()
	_button.name = "Interact"
	_button.size = Vector2(136, 168)
	_button.position = Vector2(_x, 20)
	_button.focus_mode = Control.FOCUS_NONE
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_child(_button)
	_button.pressed.connect(_on_click)
	_body = TextureRect.new()
	_body.name = "Expression"
	_body.position = Vector2(2, 24)
	_body.size = Vector2(132, 140)
	_body.pivot_offset = Vector2(66, 132)
	_body.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_body.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_body.texture = load(art)
	var blur := ShaderMaterial.new()
	blur.shader = DEFOCUS
	_body.material = blur
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.add_child(_body)
	_bubble = Panel.new()
	_bubble.position = Vector2(65, -10)
	_bubble.size = Vector2(76, 46)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = Color.BLACK
	style.set_border_width_all(3)
	style.set_corner_radius_all(22)
	_bubble.add_theme_stylebox_override(&"panel", style)
	_button.add_child(_bubble)
	for dot_index in 2:
		var dot := Panel.new()
		dot.position = Vector2(-4 - dot_index * 11, 35 + dot_index * 13)
		dot.size = Vector2.ONE * (14 - dot_index * 5)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.add_theme_stylebox_override(&"panel", style)
		_bubble.add_child(dot)
	var dots := Label.new()
	dots.text = "···"
	dots.position = Vector2(12, -9)
	dots.size = Vector2(54, 50)
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dots.add_theme_font_size_override(&"font_size", 35)
	dots.add_theme_color_override(&"font_color", Color.BLACK)
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(dots)
	_bubble.hide()


func set_thinking(value: bool, show_bubble: bool = true) -> void:
	thinking = value
	_walking = false
	if _bubble != null:
		_bubble.visible = value and show_bubble


func _on_click() -> void:
	_bounce = 1.0
	interacted.emit(member_id, thinking)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _body == null:
		return
	_time += delta
	_bounce = maxf(0, _bounce - delta * 2.2)
	if not thinking and walk_frequency > 0:
		_wait -= delta * (1.0 if _walking else walk_frequency)
		if _wait <= 0:
			_walking = not _walking
			_wait = _rng.randf_range(1.1, 2.8) if _walking else _rng.randf_range(0.6, 1.8)
		if _walking:
			_x += _direction * delta * 48
			if _x < 0 or _x > lane_width - 136:
				_direction *= -1
				_x = clampf(_x, 0, lane_width - 136)
	var walk_hop := absf(sin(_time * 8.0)) * 26 if _walking and not thinking else sin(_time * 2.5) * 3
	var click_hop := sin(_bounce * PI) * 48
	_button.position.x = _x
	_body.position.y = 24 - walk_hop - click_hop
	_body.rotation = sin(_time * 8.0) * 0.085 if _walking and not thinking else 0.0
	var squash := sin(_bounce * PI) * 0.18
	_body.scale = Vector2(1 - squash * 0.5, 1 + squash)
	if thinking:
		_bubble.position.y = -14 + sin(_time * 2) * 3
