class_name MapSystem
extends RefCounted
## RPG Maker 式「事件转移」（场所移动）的接口。
##
## 剧本里写一行就能换版图 + 指定落点：
##   [signal arg="transfer:trial/SpawnFromMain"]
##      ↑ 地图 id   ↑ 落点 id（地图里 MapSpawn 标记的 spawn_id / 节点名）
##
## 也可以只写地图 id（落在该地图的默认落点，见 MapSpawn.is_default）：
##   [signal arg="transfer:trial"]
##
## 老通道还留着：`goto:res://xxx.tscn` 直接按路径切场景（不带落点）。
##
## 三件事在这里：
##   ① 地图登记表（id → 场景路径），剧本只认 id，不再硬编码 res:// 路径
##   ② 落点请求：切场景前先把落点存下来，新地图的玩家 _ready 时自己去取（MapSpawn）
##   ③ 黑场过渡：交给 MapTransition（挂在 /root 上，换场景时不会被一起换掉）

## 注册的地图：id → 地图场景（每张地图是独立的 .tscn）
const MAPS := {
	"main": "res://grid_movement/exploration.tscn",
	"trial": "res://grid_movement/exploration_trial.tscn",
}

## 开局进哪张地图（测试房间2 = 试用场景那张手绘板）
const DEFAULT_MAP := "trial"
## 外壳场景（常驻舞台，地图是它的孩子）
const SHELL_SCENE := "res://game.tscn"

## 自检用：只记录请求，不真的切场景（否则自检场景自己会被换掉）
static var dry_run: bool = false
## 最近一次转移请求：{map, spawn, path, raw}
static var last_request: Dictionary = {}
## 转移历史（调试/自检用）
static var history: Array[Dictionary] = []
## 还没被消费的落点请求（新地图的玩家取走）
static var _pending: Dictionary = {}


static func has_map(map_id: String) -> bool:
	return MAPS.has(map_id)


static func scene_path(map_id: String) -> String:
	return str(MAPS.get(map_id, ""))


## 把剧本里的目标串解析成 {map, spawn, path, raw}；不认识就返回 {}
##   "trial/SpawnFromMain" → {map: trial, spawn: SpawnFromMain, path: <trial 场景>}
##   "trial"               → {map: trial, spawn: "", ...}
##   "res://x/y.tscn"      → {map: "", spawn: "", path: res://x/y.tscn}（老写法）
static func parse_target(target: String) -> Dictionary:
	var raw := target.strip_edges()
	if raw.is_empty():
		return {}
	if raw.begins_with("res://"):
		return {"map": "", "spawn": "", "path": raw, "raw": raw}
	var parts := raw.split("/", false, 1)
	var map_id := parts[0].strip_edges()
	if not has_map(map_id):
		return {}
	var spawn := parts[1].strip_edges() if parts.size() > 1 else ""
	return {"map": map_id, "spawn": spawn, "path": scene_path(map_id), "raw": raw}


## 请求一次转移：登记落点 → 淡出 → 换地图。
## 有外壳（game.tscn）时把地图换到外壳里；没有（单独跑一张地图场景）就换根场景。
## dry_run 时只登记不发车（自检用）。
static func request(target: String) -> bool:
	var parsed := parse_target(target)
	if parsed.is_empty():
		push_error("[MapSystem] 不认识的转移目标：'%s'（可用地图：%s）" % [target, MAPS.keys()])
		return false
	last_request = parsed
	history.append(parsed)
	_pending = parsed
	if dry_run:
		return true
	var shell := _shell()
	# 老写法 goto:res://路径 没有地图 id，只能换根场景
	if shell != null and not str(parsed.get("map", "")).is_empty():
		shell.call(&"load_map", str(parsed["map"]), str(parsed.get("spawn", "")))
		return true
	MapTransition.play(str(parsed["path"]))
	return true


## 由外壳（game.gd）在换地图前登记落点
static func set_pending(map_id: String, spawn: String = "") -> void:
	if not has_map(map_id):
		return
	_pending = {
		"map": map_id,
		"spawn": spawn,
		"path": scene_path(map_id),
		"raw": "%s/%s" % [map_id, spawn],
	}


static func _shell() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"game_shell")


## 有落点请求还没被消费吗
static func has_pending() -> bool:
	return not _pending.is_empty()


## 新地图的玩家来取落点 id（取走即清，避免下次进这张地图又被挪一次）
static func consume_spawn() -> String:
	if _pending.is_empty():
		return ""
	var spawn := str(_pending.get("spawn", ""))
	_pending = {}
	return spawn


static func clear() -> void:
	last_request = {}
	history.clear()
	_pending = {}
