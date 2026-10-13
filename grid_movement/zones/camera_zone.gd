@tool
class_name CameraZone
extends Area2D
## 判定区（远瞰 / 推近用）：玩家踩进去 → 相机缩放临时改成 `zoom`，走出去自动还原。
##
## 和「调查对话拉近」共用主角的缩放栈（`ActorPlayer.request_zoom / release_zoom`）：
## 两边可以同时成立，谁后请求谁的数值生效；都收回就回到这张地图的默认缩放。
##
## 用法：把 zones/camera_zone.tscn 拖进地图 → 拖到位置 → 检查器里改 box_size / zoom。
## 编辑器里画出来的绿框只是提示（运行时看不见）。

## 缩放栈里的 key：同一张地图放多个判定区时要各起一个名字
@export var zone_id: StringName = &"overlook"
## 踩进来时相机缩放（越大 = 画面越近；远瞰用小值比如 (1.0, 1.0)）
@export var zoom: Vector2 = Vector2(1.0, 1.0):
	set(value):
		zoom = value
		queue_redraw()

## 判定区大小（像素）；也可以直接选子节点 Shape 用把手拉
@export var box_size: Vector2 = Vector2(480.0, 320.0):
	set(value):
		box_size = Vector2(maxf(value.x, 8.0), maxf(value.y, 8.0))
		_sync_shape()
		queue_redraw()

@export var editor_color: Color = Color(0.35, 1.0, 0.6):
	set(value):
		editor_color = value
		queue_redraw()

var _shape: CollisionShape2D = null
var _syncing := false


func _ready() -> void:
	# 玩家在 collision_layer 2（见 actor_player.tscn），这里只盯它
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	_shape = _ensure_shape()
	if Engine.is_editor_hint():
		_adopt_shape()
	else:
		_sync_shape()
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
	queue_redraw()


func _ensure_shape() -> CollisionShape2D:
	var found := get_node_or_null(^"Shape") as CollisionShape2D
	if found == null:
		found = CollisionShape2D.new()
		found.name = "Shape"
		add_child(found)
	return found


func _sync_shape() -> void:
	if _syncing:
		return
	if _shape == null or not is_instance_valid(_shape):
		if not is_inside_tree():
			return
		_shape = _ensure_shape()
	var rect := _shape.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		_shape.shape = rect
	rect.size = box_size
	_shape.position = Vector2.ZERO


## 编辑器里如果人手拖了 Shape 的把手，就以形状为准读回 box_size（不然重开场景就被覆盖回去）
func _adopt_shape() -> void:
	var rect := _shape.shape as RectangleShape2D if _shape != null else null
	if rect == null or rect.size.is_equal_approx(box_size):
		return
	_syncing = true
	box_size = rect.size
	_syncing = false
	queue_redraw()


#region 玩家进出
################################################################################

func _on_body_entered(body: Node2D) -> void:
	var avatar := body as ActorPlayer
	if avatar == null:
		return
	avatar.request_zoom(zone_id, zoom)


func _on_body_exited(body: Node2D) -> void:
	var avatar := body as ActorPlayer
	if avatar == null:
		return
	avatar.release_zoom(zone_id)
#endregion


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var box := Rect2(-box_size * 0.5, box_size)
	draw_rect(box, Color(editor_color.r, editor_color.g, editor_color.b, 0.12), true)
	draw_rect(box, Color(editor_color.r, editor_color.g, editor_color.b, 0.8), false, 2.0)
	draw_string(ThemeDB.fallback_font, box.position + Vector2(6.0, 20.0),
		"%s → zoom %s" % [zone_id, zoom], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16,
		Color(editor_color.r, editor_color.g, editor_color.b, 0.95))
