class_name Grid
extends TileMapLayer

enum CellType {
	ACTOR,
	OBSTACLE,
	OBJECT,
}

@export var dialogue_ui: Node

func _ready() -> void:
	for child in get_children():
		if not "type" in child:
			continue        # 自由移动的主角没有 type，不参与格子记账
		set_cell(local_to_map((child as Node2D).position), child.type, Vector2i.ZERO)
	clean_stale_cells()


func get_cell_pawn(cell: Vector2i, type: CellType = CellType.ACTOR) -> Node2D:
	for node in get_children():
		if not "type" in node or node.type != type:
			continue
		if local_to_map(node.position) == cell:
			return node

	return null


func request_move(pawn: Pawn, direction: Vector2i) -> Vector2i:
	var cell_start := local_to_map(pawn.position)
	var cell_target := cell_start + direction

	var cell_tile_id := get_cell_source_id(cell_target)
	match cell_tile_id:
		-1:
			set_cell(cell_target, CellType.ACTOR, Vector2i.ZERO)
			set_cell(cell_start, -1, Vector2i.ZERO)
			return map_to_local(cell_target)

		CellType.OBJECT, CellType.ACTOR:
			var target_pawn := get_cell_pawn(cell_target, cell_tile_id)
			# 格子标记与实体不同步时（比如别处直接改过 position、或移动被打断）会拿到 null。
			# 以前这里会直接 target_pawn.has_node(...) → 报 has_node on null，
			# 而且返回 ZERO 变成一堵“空气墙”（人卡在外面进不去）。
			# 现在把这种脏格子当成空地，顺手清掉残留标记，自愈。
			if target_pawn == null:
				set_cell(cell_target, CellType.ACTOR, Vector2i.ZERO)
				set_cell(cell_start, -1, Vector2i.ZERO)
				return map_to_local(cell_target)

			if not target_pawn.has_node(^"DialoguePlayer"):
				return Vector2i.ZERO

			dialogue_ui.show_dialogue(pawn, target_pawn.get_node(^"DialoguePlayer"))

	return Vector2i.ZERO


## 清掉所有“标记了占位但没有实体”的脏格子（它们会变成空气墙 + 让 request_move 报错）。
## 过场动画、传送、测试脚本挪过人之后调一下；_ready 也会调一次兜底。
## 返回清掉的格子数。
func clean_stale_cells() -> int:
	var cleaned := 0
	for cell: Vector2i in get_used_cells():
		var src: int = get_cell_source_id(cell)
		if src < 0 or src > 2:
			continue
		if get_cell_pawn(cell, src) == null:
			set_cell(cell, -1, Vector2i.ZERO)
			cleaned += 1
	return cleaned


## 把某个 pawn 的格子标记同步到它当前实际位置。
## 任何“直接改 position”的地方（过场、传送、测试脚本）都该在之后调一下，
## 否则格子标记会指向一个空位，变成空气墙 + request_move 报错。
func resync_pawn(node: Node2D) -> void:
	if not "type" in node:
		return          # 自由移动的主角不参与格子记账
	var pawn := node as Pawn
	var home := local_to_map(pawn.position)
	for cell: Vector2i in get_used_cells():
		if cell == home:
			continue
		var src: int = get_cell_source_id(cell)
		if src < 0 or (src != pawn.type):
			continue
		if get_cell_pawn(cell, src) == pawn:
			set_cell(cell, -1, Vector2i.ZERO)
	set_cell(home, pawn.type, Vector2i.ZERO)
