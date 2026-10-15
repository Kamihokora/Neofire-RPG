extends Node
## 单次飞牌：弧线位置与姿态并行补间，结束后尾焰自行消退。

const FlameTrail := preload("res://combat/battle/flame_trail.gd")


func fly(view: BattleCardView, destination: Vector2, angle: float, card_scale: float, duration: float, delay: float = 0, departing: bool = false) -> void:
	if delay > 0:
		await get_tree().create_timer(delay).timeout
	if not is_instance_valid(view):
		return
	var trail := FlameTrail.new()
	trail.target = view
	get_parent().add_child(trail)
	var start := view.global_position
	var control := (start + destination) * 0.5 - Vector2(0, 130 if departing else 160)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN if departing else Tween.EASE_OUT)
	tween.tween_method(func(t: float) -> void:
		view.global_position = start.lerp(control, t).lerp(control.lerp(destination, t), t), 0.0, 1.0, duration)
	tween.tween_property(view, ^"rotation", angle, duration)
	tween.tween_property(view, ^"scale", Vector2.ONE * card_scale, duration)
	if departing:
		tween.tween_property(view, ^"modulate:a", 0.0, duration * 0.25).set_delay(duration * 0.75)
	await tween.finished
	trail.stop()
