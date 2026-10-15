extends Control
## 尾部独立于云朵素材；跟随文手头顶或笔记本加号，不绑定角色贴图尺寸。

var _start := Vector2.ZERO
var _target := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func point_to(origin: Vector2, target: Vector2) -> void:
	if _start.is_equal_approx(origin) and _target.is_equal_approx(target): return
	_start = origin
	_target = target
	queue_redraw()


func _draw() -> void:
	for index in 3:
		var progress: float = [0.23, 0.56, 0.94][index]
		var radius: float = [37.0, 24.0, 12.0][index]
		var center := _start.lerp(_target, progress)
		draw_set_transform(center, -0.15, Vector2(1, 0.58))
		draw_circle(Vector2.ZERO, radius, Color("17171d"), true, -1, true)
		draw_circle(Vector2.ZERO, radius - 3, Color("fffdf7"), true, -1, true)
	draw_set_transform(Vector2.ZERO)
