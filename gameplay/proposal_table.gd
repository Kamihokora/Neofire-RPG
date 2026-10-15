@tool
extends Node2D
## 拖入休息区地图即可；由玩家既有近距离E/F交互打开四人桌页面。

@export var occupied := false:
	set(value):
		occupied = value
		queue_redraw()


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"proposal_table")
	if Engine.is_editor_hint(): return
	var label := Label.new()
	label.text = "四人桌"
	label.position = Vector2(-38, -64)
	label.add_theme_font_override(&"font", load("res://theme/fonts/思源黑体.otf"))
	label.add_theme_font_size_override(&"font_size", 20)
	label.add_theme_constant_override(&"outline_size", 4)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	add_child(label)


func _draw() -> void:
	for seat: Vector2 in [Vector2(-39, 0), Vector2(39, 0), Vector2(0, -31), Vector2(0, 31)]:
		draw_circle(seat, 11, Color("22222a"))
		draw_arc(seat, 11, 0, TAU, 24, Color.WHITE, 2, true)
	draw_rect(Rect2(-29, -22, 58, 44), Color("4b3446") if occupied else Color("c14060"))
	draw_rect(Rect2(-29, -22, 58, 44), Color.WHITE, false, 3)


func is_available(player: Node2D) -> bool:
	return not occupied and is_visible_in_tree() and player is ActorPlayer and global_position.distance_to(player.global_position) <= float(player.talk_range)


func interact_with(player: Node2D) -> bool:
	if not is_available(player): return false
	var game := get_tree().get_first_node_in_group(&"game_shell")
	if game == null: return false
	game.phone.open_meeting(self)
	return game.phone.is_open
