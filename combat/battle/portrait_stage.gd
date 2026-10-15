extends Node2D
## 左侧常驻的斜切舞台；同一裁切轮廓内交换立绘，不移动血条和点击区。

const NORMAL := "res://assets/portraits/xinhuo_normal.png"
const WRITER := "res://neofire/Neofire-write.png"
const GLOW := preload("res://combat/battle/portrait_glow.gdshader")

var art: TextureRect
var glow: ShaderMaterial
var particles: CPUParticles2D
var writer := false
var _accent: Polygon2D
var _tween: Tween


func _ready() -> void:
	position = Vector2(28, 128)
	_polygon(self, PackedVector2Array([Vector2(88, 42), Vector2(478, 0), Vector2(414, 482), Vector2(0, 516)]), Color(0.025, 0.02, 0.035, 0.93))
	_accent = _polygon(self, PackedVector2Array([Vector2(62, 50), Vector2(458, 10), Vector2(398, 470), Vector2(0, 494)]), Color(0.76, 0.12, 0.18))
	var mask := _polygon(self, PackedVector2Array([Vector2(76, 62), Vector2(447, 23), Vector2(385, 457), Vector2(11, 482)]), Color(0.08, 0.045, 0.08))
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	for i in 8:
		var y := 70.0 + i * 61
		_polygon(mask, PackedVector2Array([Vector2(10, y + 19), Vector2(460, y - 28), Vector2(460, y - 19), Vector2(10, y + 28)]), Color(0.23, 0.1, 0.15, 0.5))
	art = TextureRect.new()
	art.name = "Art"
	art.position = Vector2(8, 4)
	art.size = Vector2(448, 570)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow = ShaderMaterial.new()
	glow.shader = GLOW
	art.material = glow
	mask.add_child(art)
	_set_art(false)
	_polygon(self, PackedVector2Array([Vector2(0, 503), Vector2(400, 464), Vector2(397, 473), Vector2(4, 514)]), Color(1, 0.82, 0.65))
	particles = CPUParticles2D.new()
	particles.name = "TransformParticles"
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 72
	particles.lifetime = 0.85
	particles.explosiveness = 0.55
	particles.position = Vector2(234, 252)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(155, 200)
	particles.direction = Vector2.UP
	particles.spread = 120
	particles.gravity = Vector2(0, -85)
	particles.initial_velocity_min = 38
	particles.initial_velocity_max = 170
	particles.scale_amount_min = 0.18
	particles.scale_amount_max = 0.45
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var dot := GradientTexture2D.new()
	dot.gradient = gradient
	dot.width = 16
	dot.height = 16
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1, 0.5)
	particles.texture = dot
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	particles.color_ramp = fade
	add_child(particles)


func transform_to(as_writer: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var rise := 0.36 if as_writer else 0.14
	var settle := 0.42 if as_writer else 0.2
	particles.restart()
	particles.emitting = true
	_tween = create_tween()
	_tween.tween_method(_set_flash, 0.0, 1.0, rise).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(_set_art.bind(as_writer))
	_tween.tween_interval(0.08 if as_writer else 0.035)
	_tween.tween_method(_set_flash, 1.0, 0.0, settle).set_trans(Tween.TRANS_SINE)
	await _tween.finished


func _set_flash(value: float) -> void:
	glow.set_shader_parameter(&"flash", value)


func _set_art(as_writer: bool) -> void:
	writer = as_writer
	var crop := AtlasTexture.new()
	crop.atlas = load(WRITER if as_writer else NORMAL)
	crop.region = Rect2(220, 100, 1240, 1560) if as_writer else Rect2(535, 90, 850, 1080)
	art.texture = crop
	_accent.color = Color(0.06, 0.65, 0.72) if as_writer else Color(0.76, 0.12, 0.18)


func _polygon(parent: Node, points: PackedVector2Array, color: Color) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.polygon = points
	polygon.color = color
	parent.add_child(polygon)
	return polygon
