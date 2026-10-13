@tool
class_name ActorNpc
extends CharacterBody2D
## 用 Actor 图版的活动角色：敌人（站着不动，面朝左）或队友（跟着队尾走）。
##
## 队友的跟随是 RPG Maker 那套「沿着队长的足迹走」：
## 队长每移动 8px 记一个轨迹点，第 i 个跟随者站在队长 `(i+1) * follow_spacing` 距离之前的位置上，
## 所以队伍会像一条蛇一样拐弯，而不是直线飘过去。

const TRAIL_SAMPLE := 8.0        # 队长每走这么多像素记一个点
const TRAIL_MAX := 600

@export_group("外观")
## 用图版里第几个角色（0 起，先横后纵）
@export var character_index: int = 1
@export var walk_fps: float = 8.0
## 站着时朝哪（4 向）
@export var idle_facing: Vector2i = Vector2i.DOWN
## 静止时是否看向玩家（敌人用）
@export var face_player: bool = false

@export_group("跟随")
## 留空 = 不跟随（站着不动的 NPC/敌人）
@export var leader_path: NodePath
## 第几个跟随者（0 = 紧跟在队长身后）
@export var party_index: int = 0
## 队尾间距（像素）
@export var follow_spacing: float = 44.0
@export var move_speed: float = 230.0

@onready var _sprite: AnimatedSprite2D = $Sprite

var _leader: Node2D = null
var _facing: Vector2i = Vector2i.DOWN


func _ready() -> void:
	# 编辑器里什么都不做（只画个占位框，见 _draw）
	if Engine.is_editor_hint():
		queue_redraw()
		return
	_facing = idle_facing
	_sprite.sprite_frames = ActorSheet.build_frames(character_index, walk_fps)
	_play_idle()
	if leader_path.is_empty():
		pass
	else:
		add_to_group(&"party_follower")
		_leader = get_node_or_null(leader_path) as Node2D
		if _leader == null:
			# 允许写 ../Player 之外的简写：找不到就全局找一下名字
			_leader = get_tree().get_first_node_in_group(&"player") as Node2D
		if _leader == null:
			push_warning("[ActorNpc] 找不到跟随目标：%s" % leader_path)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _leader != null and is_instance_valid(_leader):
		_follow()
	elif face_player:
		_face_towards_player()


## 编辑器占位框：角色的行走图是运行时按 character_index 从 Actor1.png 切的，
## 编辑器里看不到 → 不画个框就根本找不到事件在哪、也没法拖。
## （只画，不往节点上写任何属性，所以不会把贴图数据存进 .tscn）
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var half := ActorSheet.FRAME_SIZE * 0.5
	var rect := Rect2(Vector2(-half, -half), Vector2(ActorSheet.FRAME_SIZE, ActorSheet.FRAME_SIZE))
	draw_rect(rect, Color(0.35, 0.75, 1.0, 0.22), true)
	draw_rect(rect, Color(0.45, 0.85, 1.0, 0.9), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-half, -half - 4.0),
		"#%d" % character_index, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.85, 0.95, 1.0))


#region 跟随（RPG Maker 式跟足迹）
################################################################################

func _follow() -> void:
	var target: Vector2 = _leader.call(&"trail_point", party_index) if _leader.has_method(&"trail_point") else _leader.global_position
	var to_target := target - global_position
	if to_target.length() <= 2.0:
		velocity = Vector2.ZERO
		move_and_slide()
		_play_idle()
		return
	var dir := to_target.normalized()
	velocity = dir * move_speed
	move_and_slide()
	_facing = ActorSheet.direction_from_vector(dir)
	_play(&"walk")


func _face_towards_player() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		_play_idle()
		return
	_facing = ActorSheet.direction_from_vector(player.global_position - global_position)
	_play_idle()
#endregion


func _play(kind: String) -> void:
	var anim := ActorSheet.anim_name(_facing, kind)
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(anim) and _sprite.animation != anim:
		_sprite.play(anim)


func _play_idle() -> void:
	_play("idle")
