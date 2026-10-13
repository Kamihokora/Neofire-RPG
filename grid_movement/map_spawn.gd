class_name MapSpawn
extends Marker2D
## 地图落点（RPG Maker「场所移动」的目的地）。
##
## 放在地图场景里，spawn_id 就是剧本里写的那一段：
##   [signal arg="transfer:trial/SpawnFromMain"]  → 落在 spawn_id = "SpawnFromMain" 的这里
##
## 一张地图可以放多个落点（从主房间去野外、从野外回房间各一个）。

## 落点 id（留空就用节点名）
@export var spawn_id: StringName = &""
## 没有指定 spawn_id 时，是否作为这张地图的默认落点
@export var is_default: bool = false
## 到达时朝哪（4 向，和 ActorSheet 一致）
@export var facing: Vector2i = Vector2i.DOWN


func _ready() -> void:
	add_to_group(&"map_spawn")


## 在本地图范围内找落点：want 先按 spawn_id 匹配，再按节点名匹配；
## want 为空时找 is_default 的那个（没有就找第一个）。
## scope 限定了"哪张地图"，避免自检里同时存在两张地图时找错。
static func find(want: String, scope: Node = null) -> MapSpawn:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var first: MapSpawn = null
	var fallback: MapSpawn = null
	for node: Node in tree.get_nodes_in_group(&"map_spawn"):
		var spawn := node as MapSpawn
		if spawn == null or not is_instance_valid(spawn):
			continue
		if scope != null and not scope.is_ancestor_of(spawn):
			continue
		if first == null:
			first = spawn
		if spawn.is_default and fallback == null:
			fallback = spawn
		if want.is_empty():
			continue
		if String(spawn.spawn_id) == want or String(spawn.name) == want:
			return spawn
	if not want.is_empty():
		return null
	return fallback if fallback != null else first
