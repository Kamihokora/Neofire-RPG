@tool
extends Node2D
## 调查/宝箱可复用的获得接口；lost随现有地图存档保存，不重复领取。

@export var word_id := "test1"
@export_range(1, 999) var amount := 1
@export_range(0, 100000) var experience_reward := 0
var lost := false


func _ready() -> void:
	add_to_group(&"interactable")


func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -22), Vector2(11, -22), Vector2(19, -14), Vector2(19, 21), Vector2(-14, 21)]), Color("ffdf80"))
	for y: float in [-10, 0, 10]:
		draw_line(Vector2(-7, y), Vector2(11, y), Color("40324a"), 2)


func interact_with(player: Node2D) -> bool:
	if lost or not player is ActorPlayer or global_position.distance_to(player.global_position) > float(player.talk_range):
		return false
	var state := RunState.instance
	if not word_id.is_empty() and not state.journey.add_inspiration(word_id, amount):
		return false
	if experience_reward > 0: state.journey.award_experience(experience_reward, state)
	lost = true
	hide()
	var label := Label.new()
	label.text = "获得灵感 ×%d" % amount
	label.position = position + Vector2(-40, -35)
	label.add_theme_font_size_override(&"font_size", 22)
	get_parent().add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, ^"position:y", label.position.y - 40, 1.0)
	tween.tween_property(label, ^"modulate:a", 0.0, 0.6).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)
	return true
