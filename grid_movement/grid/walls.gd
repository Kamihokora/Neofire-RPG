class_name GridWalls
extends StaticBody2D
## 由地图图层生成碰撞盒（自由移动用）。
##
## 规则：源图层里 source_id >= 3 的格子算墙 —— 这跟原来格子移动的判定完全一致
## （0/1/2 是玩家/障碍/物件标记），所以改成自由移动后"哪里能走"没有变化。
##
## 横向连续的墙会合并成一个矩形，1021 个格子最后只剩几十个碰撞盒。
##
## 换成手绘地图后你有两条路：
##   ① 继续在这个图层上画墙（src>=3），启动时自动生成；
##   ② 或不想要自动生成，就把本节点的脚本摘掉、自己摆 StaticBody2D/CollisionShape2D。

@export var source_layer_path: NodePath = ^"../Grid"
## 格子尺寸（跟图层一致；留 0 表示从图层自动取）
@export var cell_size: int = 0
## 碰撞盒高度占格子的比例（1.0 = 整格；横版常用 0.5~0.7，只挡下半截）
@export var height_ratio: float = 1.0
## 自动把地图范围设成相机边界
@export var apply_camera_limits: bool = true

## 源图层的世界变换（碰撞盒要跟着图层走）
var _layer_to_global := Transform2D.IDENTITY


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.queue_free()

	var layer := get_node_or_null(source_layer_path) as TileMapLayer
	if layer == null:
		push_warning("[GridWalls] 找不到源图层：%s" % source_layer_path)
		return
	var size := cell_size
	if size <= 0:
		size = int(layer.tile_set.tile_size.x) if layer.tile_set != null else 64

	# 记下图层的世界变换：碰撞盒要放在"图层所在的位置"，不能假设图层在原点
	# （game.tscn 里 Exploration 有偏移、图层自己也可能有 position，对不齐就是这么来的）
	_layer_to_global = layer.global_transform
	# 收集墙格并按行合并成横向连续段
	var runs_by_row := {}
	for cell: Vector2i in layer.get_used_cells():
		if layer.get_cell_source_id(cell) < 3:
			continue
		runs_by_row.get_or_add(cell.y, []).append(cell.x)

	var count := 0
	for y: int in runs_by_row:
		var xs: Array = runs_by_row[y]
		xs.sort()
		var run_start: int = xs[0]
		var prev: int = xs[0]
		for i in range(1, xs.size() + 1):
			var x: int = xs[i] if i < xs.size() else prev + 2   # 末尾补一个断开值，收尾
			if x != prev + 1:
				_add_run(run_start, prev, y, size)
				count += 1
				run_start = x
			prev = x

	if apply_camera_limits:
		_apply_camera_limits(layer, size)
	print("[GridWalls] 生成 %d 个碰撞盒（格子 %dpx）" % [count, size])


func _add_run(x_from: int, x_to: int, y: int, size: int) -> void:
	var cells := float(x_to - x_from + 1)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(cells * size, size * height_ratio)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	# 以格子中心为基准；height_ratio < 1 时贴格子底部
	var center := Vector2((x_from + x_to + 1) * 0.5 * size, (y + 0.5) * size)
	center.y += size * (1.0 - height_ratio) * 0.5
	# 格子坐标 → 图层世界坐标 → 本节点局部坐标
	collider.position = to_local(_layer_to_global * center)
	add_child(collider)


## 地图范围 → 相机边界（地图比屏幕大时才不会拍到外面）。
## 取同级所有 TileMapLayer 的并集，只看 Grid 图层会偏小。
func _apply_camera_limits(layer: TileMapLayer, size: int) -> void:
	var camera := _map_camera()
	if camera == null:
		push_warning("[GridWalls] 没找到本地图的主角相机，相机边界没设上")
		return
	var rect := layer.get_used_rect()
	var parent := layer.get_parent()
	if parent != null:
		for sibling in parent.get_children():
			if sibling is TileMapLayer and sibling != layer:
				var other: Rect2i = (sibling as TileMapLayer).get_used_rect()
				if other.size.x > 0 and other.size.y > 0:
					rect = rect.merge(other)
	# 格子矩形 → **世界坐标**。
	# 以前这里直接拿 rect * size（格子坐标）当边界，忽略了图层自己以及外层地图容器的偏移，
	# 于是边界整块偏移（game.tscn 的 MapHost 偏 (-524,-86)），相机一开局就被顶在左边/上边，
	# 人走远了相机不跟、乃至走出画面。
	var world: Rect2 = _layer_to_global * Rect2(Vector2(rect.position) * size, Vector2(rect.size) * size)
	camera.limit_left = roundi(world.position.x)
	camera.limit_top = roundi(world.position.y)
	camera.limit_right = roundi(world.end.x)
	camera.limit_bottom = roundi(world.end.y)


## 只认"自己这张地图里"的主角相机。
## 场上同时存在别的地图实例时（编辑器里并排开两张地图、自检里叠着实例），
## get_first_node_in_group("player_camera") 可能拿到别家的相机 → 边界写到一台没启用的相机上，
## 表现就是"相机不跟人走 / 拍到地图外面"。
func _map_camera() -> Camera2D:
	var map: Node = owner if owner != null else get_parent()
	var fallback: Camera2D = null
	for node: Node in get_tree().get_nodes_in_group(&"player_camera"):
		var camera := node as Camera2D
		if camera == null:
			continue
		if map != null and map.is_ancestor_of(camera):
			return camera
		if fallback == null:
			fallback = camera
	return fallback
