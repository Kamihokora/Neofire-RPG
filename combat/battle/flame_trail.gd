extends Node2D
## 参考 StS2 NCardTrail：按距离采样、按寿命消退；火舌与余烬为原生绘制。

var target: Control
var _points: Array[Vector3] = []
var _embers: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _emitting := true
const LIFE := 0.28


func _ready() -> void:
	z_index = 24
	_rng.randomize()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive


func stop() -> void:
	_emitting = false


func _process(delta: float) -> void:
	_time += delta
	for index in range(_points.size() - 1, -1, -1):
		_points[index].z += delta
		if _points[index].z > LIFE:
			_points.remove_at(index)
	if _emitting and is_instance_valid(target):
		var head := target.get_global_transform() * (target.size * 0.5)
		if _points.is_empty() or Vector2(_points[-1].x, _points[-1].y).distance_to(head) >= 6:
			_points.append(Vector3(head.x, head.y, 0))
			_embers.append({"at": head, "velocity": Vector2(_rng.randf_range(-50, 50), _rng.randf_range(-100, -35)), "age": 0.0})
	for index in range(_embers.size() - 1, -1, -1):
		_embers[index]["age"] += delta
		_embers[index]["at"] += _embers[index]["velocity"] * delta
		if _embers[index]["age"] > 0.36:
			_embers.remove_at(index)
	queue_redraw()
	if (not _emitting or not is_instance_valid(target)) and _points.is_empty() and _embers.is_empty():
		queue_free()


func _draw() -> void:
	for index in range(1, _points.size()):
		var a := Vector2(_points[index - 1].x, _points[index - 1].y)
		var b := Vector2(_points[index].x, _points[index].y)
		var heat := 1.0 - _points[index].z / LIFE
		var normal := (b - a).normalized().orthogonal()
		draw_line(a, b, Color(1, 0.13, 0.015, heat * 0.35), 30 * heat, true)
		draw_line(a, b, Color(1, 0.48, 0.04, heat * 0.75), 13 * heat, true)
		draw_line(a, b, Color(1, 0.9, 0.4, heat), maxf(1, 3 * heat), true)
		var flutter := sin(_time * 32 + index * 2.1) * (12 + 14 * heat)
		if absf(flutter) > 0.5 and a.distance_squared_to(b) > 4:
			var tip := (a + b) * 0.5 + normal * flutter
			draw_colored_polygon(PackedVector2Array([a, tip, b]), Color(1, 0.3, 0.02, heat * 0.4))
	for ember: Dictionary in _embers:
		draw_circle(ember["at"], 2.1 * (1 - ember["age"] / 0.36), Color(1, 0.65, 0.12, 1 - ember["age"] / 0.36))
