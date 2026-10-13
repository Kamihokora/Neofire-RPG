@tool
class_name CollisionBlock
extends StaticBody2D
## 手绘地图用的碰撞箱：**在编辑器里拖就行**。
##
## 用法（三种都行，随便挑）：
##   ① 把 blocks/collision_block.tscn 拖进房间场景，想放多少放多少，再拖动位置
##   ② 选中它 → 检查器里改 box_size（宽 × 高，单位像素）
##   ③ 选中子节点 Shape → 视口工具栏会出现矩形把手，直接用鼠标拉伸
##
## `height_ratio < 1` = 只挡下半截（横版常用 0.5~0.7），语义和 grid_movement/grid/walls.gd 一致。
## 编辑器里画出来的粉框只是提示（运行时看不见，地图美术才是画面）。

@export var box_size: Vector2 = Vector2(64.0, 48.0):
	set(value):
		box_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_sync_shape()
		queue_redraw()

## 只挡下半截的比例（1 = 整块都挡）
@export_range(0.1, 1.0, 0.05) var height_ratio: float = 1.0:
	set(value):
		height_ratio = clampf(value, 0.1, 1.0)
		_sync_shape()
		queue_redraw()

## 编辑器里的提示颜色
@export var editor_color: Color = Color(1.0, 0.32, 0.42):
	set(value):
		editor_color = value
		queue_redraw()

var _shape: CollisionShape2D = null
var _syncing := false


func _ready() -> void:
	_shape = _ensure_shape()
	if Engine.is_editor_hint():
		# 编辑器里以手拖出来的形状为准（不然重开场景就被 box_size 覆盖回去了）
		_adopt_shape()
	else:
		_sync_shape()
	queue_redraw()


func _ensure_shape() -> CollisionShape2D:
	var found := get_node_or_null(^"Shape") as CollisionShape2D
	if found == null:
		# 场景里本来就有 Shape；用户删了才现建（owner 留空，不会被存进 .tscn）
		found = CollisionShape2D.new()
		found.name = "Shape"
		add_child(found)
	return found


## 碰撞形状跟着 box_size / height_ratio 走
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
	rect.size = Vector2(box_size.x, box_size.y * height_ratio)
	# height_ratio < 1 时贴格子底部（和 walls.gd 的手感一致）
	_shape.position = Vector2(0.0, box_size.y * (1.0 - height_ratio) * 0.5)


## 编辑器里人手拖了 Shape 把手 → 读回 box_size（和 CameraZone 同一套做法）
func _adopt_shape() -> void:
	var rect := _shape.shape as RectangleShape2D if _shape != null else null
	if rect == null:
		return
	var implied := Vector2(box_size.x, box_size.y * height_ratio)
	if rect.size.is_equal_approx(implied):
		return
	_syncing = true
	box_size = Vector2(rect.size.x, rect.size.y / maxf(height_ratio, 0.01))
	_syncing = false
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var box := Rect2(-box_size * 0.5, box_size)
	draw_rect(box, Color(editor_color.r, editor_color.g, editor_color.b, 0.18), true)
	draw_rect(box, Color(editor_color.r, editor_color.g, editor_color.b, 0.85), false, 2.0)
	# 实际挡住的区域（height_ratio 那部分）画实一点
	var solid := Rect2(
		Vector2(-box_size.x * 0.5, -box_size.y * 0.5 + box_size.y * (1.0 - height_ratio)),
		Vector2(box_size.x, box_size.y * height_ratio))
	draw_rect(solid, Color(editor_color.r, editor_color.g, editor_color.b, 0.45), true)
