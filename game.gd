@tool
extends Node
## 游戏外壳：一张常驻的舞台，地图（.tscn）作为它的孩子在 MapHost 下换进换出。
##
## ⚠ 这个场景在编辑器里是空的（正常，地图是运行时加载的）：
##   要摆地图 / 事件 / 碰撞箱，请直接打开
##     grid_movement/exploration.tscn        测试房间1（tilemap，含碰撞图层）
##     grid_movement/exploration_trial.tscn  测试房间2（手绘背景板）
##   编辑器里这个场景会显示一段提示（只存在于编辑器，不会被存进 .tscn）。
##
## 为什么不让每张地图自己当根场景：
##   · 换地图时相机 / 对话画布 / 黑场层都要重建 → 画面会跳，切换很突兀
##   · 地图当孩子换，外壳的 Dialogic 布局、战斗层、淡入淡出都留着，过渡就是一次淡黑
##
## 换地图统一走 MapSystem.request("trial/SpawnFromMain")，或者直接 load_map(...)：
## 同一时刻 MapHost 下只有一张地图，旧地图立刻摘下来（不会出现"两支队"的鬼影）。
##
## 两张地图都是独立的 .tscn：
##   grid_movement/exploration.tscn       主房间
##   grid_movement/exploration_trial.tscn 试用场景

const PLAYER_WIN := "res://dialogue/dialogic/timelines/player_won.dtl"
const PLAYER_LOSE := "res://dialogue/dialogic/timelines/player_lose.dtl"
const PhoneMenu := preload("res://ui/phone_menu.gd")
const SaveStore := preload("res://gameplay/save_store.gd")
const DialogueDriver := preload("res://dialogue/dialogue_player/dialogue_player.gd")

@export var combat_screen: CanvasLayer
## 地图挂载点：所有地图都挂在这下面
@export var map_host: Node2D

## 当前地图（同一时刻只有一张）
var current_map: Node2D = null

var _switching := false
var current_map_id := ""
var save_store := SaveStore.new()
var phone: PhoneMenu
var _map_states: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		_show_editor_hint()
		return
	add_to_group(&"game_shell")
	combat_screen.battle_finished.connect(_on_battle_finished)
	remove_child(combat_screen)
	phone = PhoneMenu.new()
	phone.name = "PhoneMenu"
	add_child(phone)
	phone.configure(self, save_store)
	phone.save_requested.connect(save_game)
	phone.load_requested.connect(load_game)
	load_map(MapSystem.DEFAULT_MAP, "", true)


#region 编辑器提示（只存在于编辑器，不进场景）
################################################################################

## 编辑器里立一块牌子：地图不在这个场景里编辑。
## owner 留空 → 保存场景时不会被写进 .tscn（否则每存一次就多一个节点）。
func _show_editor_hint() -> void:
	if get_node_or_null(^"__editor_hint") != null:
		return
	var hint := Label.new()
	hint.name = "__editor_hint"
	hint.text = "这里是外壳，空的是正常的。\n地图请在 grid_movement/exploration.tscn（测试房间1）\n或 grid_movement/exploration_trial.tscn（测试房间2）里编辑。\n拖事件 / 加碰撞箱都在那边做。"
	hint.position = Vector2(24.0, 24.0)
	hint.add_theme_font_size_override(&"font_size", 28)
	hint.add_theme_color_override(&"font_color", Color(1.0, 0.86, 0.45))
	hint.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	hint.add_theme_constant_override(&"outline_size", 6)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	hint.owner = null
#endregion


#region 换地图（RPG Maker 式事件转移的目的地）
################################################################################

## 换到地图 map_id，并把落点请求交给新地图（新地图的玩家 _ready 时自己取）
func load_map(map_id: String, spawn: String = "", instant: bool = false) -> void:
	if _switching:
		return
	if not MapSystem.has_map(map_id):
		push_error("[Game] 没有这张地图：%s（可用：%s）" % [map_id, MapSystem.MAPS.keys()])
		return
	MapSystem.set_pending(map_id, spawn)
	_switching = true
	if not instant:
		$AnimationPlayer.play(&"fade_to_black")
		await $AnimationPlayer.animation_finished
	_swap_map(map_id)
	if not instant:
		$AnimationPlayer.play_backwards(&"fade_to_black")
		await $AnimationPlayer.animation_finished
	_switching = false


## 真正换：先把旧地图摘下来（同一时刻只留一张），再挂新的
func _swap_map(map_id: String, capture_old: bool = true) -> void:
	var path := MapSystem.scene_path(map_id)
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("[Game] 地图载入失败：%s" % path)
		return
	if current_map != null and is_instance_valid(current_map):
		if capture_old:
			_capture_map_state()
		map_host.remove_child(current_map)
		current_map.queue_free()
	current_map_id = map_id
	current_map = packed.instantiate() as Node2D
	map_host.add_child(current_map)
	_connect_map_events(current_map)
	_restore_map_state()


## 地图里"会把你拖进战斗"的东西：battle_enemy 组 + 它自己的 DialoguePlayer
func _connect_map_events(map: Node) -> void:
	for node: Node in get_tree().get_nodes_in_group(&"battle_enemy"):
		if not map.is_ancestor_of(node) or not node.has_node(^"DialoguePlayer"):
			continue
		var driver: Node = node.get_node(^"DialoguePlayer")
		if driver.has_meta(&"neofire_battle_hooked"):
			continue
		driver.set_meta(&"neofire_battle_hooked", true)
		driver.dialogue_finished.connect(_on_opponent_dialogue_finished.bind(node))


## 当前地图里的玩家（地图之外的不算）
func current_player() -> Node2D:
	if current_map == null or not is_instance_valid(current_map):
		return null
	for node: Node in get_tree().get_nodes_in_group(&"player"):
		if current_map.is_ancestor_of(node):
			return node as Node2D
	return null


## 当前地图里的对话入口
func current_dialogue_ui() -> Node:
	if current_map == null or not is_instance_valid(current_map):
		return null
	for node: Node in get_tree().get_nodes_in_group(&"dialogue_ui"):
		if current_map.is_ancestor_of(node):
			return node
	return null
#endregion


func map_display_name(map_id: String = "") -> String:
	var selected := current_map_id if map_id.is_empty() else map_id
	return str({"main": "测试房间1", "trial": "测试房间2"}.get(selected, selected))


func menu_open_reason() -> String:
	return "正在转场" if _switching or current_map == null else ""


func save_block_reason() -> String:
	if _switching or current_player() == null:
		return "转场期间暂不可存读档。"
	if combat_screen.get_parent() != null or RunState.instance.in_form():
		return "战斗期间暂不可存读档。"
	if Dialogic.current_timeline != null:
		return "对话期间暂不可存读档。"
	return ""


func _capture_map_state() -> void:
	if current_map == null:
		return
	var nodes: Dictionary = {}
	for node: Node in current_map.find_children("*", "Node2D", true, false):
		if not node.is_in_group(&"interactable") or node.is_in_group(&"party_follower") or node.is_in_group(&"player"):
			continue
		var point := current_map.to_local((node as Node2D).global_position)
		var data := {"position": [point.x, point.y], "visible": (node as CanvasItem).visible}
		if node.get(&"lost") is bool:
			data["lost"] = node.get(&"lost")
		nodes[str(current_map.get_path_to(node))] = data
	_map_states[current_map_id] = nodes


func _restore_map_state() -> void:
	var nodes: Dictionary = _map_states.get(current_map_id, {})
	for path: String in nodes:
		var node := current_map.get_node_or_null(NodePath(path)) as Node2D
		if node == null or not node.is_in_group(&"interactable") or node.is_in_group(&"party_follower"):
			continue
		var data: Dictionary = nodes[path]
		var point: Array = data["position"]
		node.global_position = current_map.to_global(Vector2(float(point[0]), float(point[1])))
		node.visible = bool(data["visible"])
		if data.has("lost") and node.get(&"lost") is bool:
			node.set(&"lost", bool(data["lost"]))


static func _valid_point(value: Variant) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for number: Variant in value:
		if not (number is int or number is float) or not is_finite(float(number)) or absf(float(number)) > 10000000:
			return false
	return true


func valid_snapshot(data: Dictionary) -> bool:
	if not MapSystem.has_map(str(data.get("map_id", ""))) or not data.get("run") is Dictionary or not RunState.valid_save_data(data["run"]):
		return false
	var travel: Variant = data.get("travel")
	if not travel is Dictionary or not _valid_point(travel.get("position")) or not _valid_point(travel.get("facing")):
		return false
	var facing: Array = travel["facing"]
	if [int(facing[0]), int(facing[1])] not in [[0, 1], [0, -1], [1, 0], [-1, 0]] or float(facing[0]) != int(facing[0]) or float(facing[1]) != int(facing[1]):
		return false
	var trail: Variant = travel.get("trail")
	if not trail is Array or trail.size() > 600:
		return false
	for point: Variant in trail:
		if not _valid_point(point):
			return false
	for key: String in ["maps", "variables", "leave_counts"]:
		if not data.get(key) is Dictionary:
			return false
	for map_id: String in data["maps"]:
		if not MapSystem.has_map(map_id) or not data["maps"][map_id] is Dictionary:
			return false
		for path: String in data["maps"][map_id]:
			if path.begins_with("/") or ".." in path.split("/"):
				return false
			var state: Variant = data["maps"][map_id][path]
			if not state is Dictionary or not _valid_point(state.get("position")) or not state.get("visible") is bool:
				return false
			if state.has("lost") and not state["lost"] is bool:
				return false
	for key: Variant in data["leave_counts"]:
		var count: Variant = data["leave_counts"][key]
		if not key is String or not (count is int or count is float) or not is_finite(float(count)) or float(count) < 0 or float(count) != floor(float(count)):
			return false
	return true


func save_game(slot: int) -> void:
	var reason := save_block_reason()
	if not reason.is_empty():
		phone.notify(reason)
		return
	_capture_map_state()
	var player := current_player() as ActorPlayer
	var data := {"map_id": current_map_id, "travel": player.capture_travel_state(),
		"run": RunState.instance.to_save_data(), "maps": _map_states.duplicate(true),
		"variables": Dialogic.VAR.var_storage.duplicate(true), "leave_counts": DialogueDriver._global_leave_counts.duplicate(true)}
	if not valid_snapshot(data):
		phone.notify("当前进度无法保存。")
		return
	var result := save_store.write_slot(slot, data)
	if phone.is_open:
		phone.show_app("save")
	phone.notify("已保存到存档 %d" % slot if result.get("ok", false) else str(result.get("error", "保存失败")))


func load_game(slot: int) -> void:
	var reason := save_block_reason()
	if not reason.is_empty():
		phone.notify(reason)
		return
	var result := save_store.read_slot(slot)
	if not result.get("ok", false) or not valid_snapshot(result.get("data", {})):
		phone.notify(str(result.get("error", "存档内容无法恢复")))
		return
	var data: Dictionary = result["data"]
	var packed := load(MapSystem.scene_path(str(data["map_id"]))) as PackedScene
	if packed == null:
		phone.notify("存档地图无法读取，当前进度已保留。")
		return
	_switching = true
	if phone.is_open:
		phone.close_phone()
		await phone.closed
	$AnimationPlayer.play(&"fade_to_black")
	await $AnimationPlayer.animation_finished
	RunState.instance.apply_save_data(data["run"])
	Dialogic.VAR.var_storage = data["variables"].duplicate(true)
	DialogueDriver._global_leave_counts = data["leave_counts"].duplicate(true)
	_map_states = data["maps"].duplicate(true)
	MapSystem.set_pending(str(data["map_id"]))
	_swap_map(str(data["map_id"]), false)
	await get_tree().process_frame
	await get_tree().process_frame
	var player := current_player() as ActorPlayer
	player.restore_travel_state(data["travel"])
	$AnimationPlayer.play_backwards(&"fade_to_black")
	await $AnimationPlayer.animation_finished
	_switching = false


#region 战斗
################################################################################

func start_combat(combat_actors: Array[PackedScene]) -> void:
	_switching = true
	$AnimationPlayer.play(&"fade_to_black")
	await $AnimationPlayer.animation_finished
	# 地图整棵停掉（玩家不会再走），而不是把它从树上摘下来
	if current_map != null and is_instance_valid(current_map):
		current_map.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(combat_screen)
	combat_screen.show()
	combat_screen.initialize(combat_actors)
	$AnimationPlayer.play_backwards(&"fade_to_black")
	await $AnimationPlayer.animation_finished
	_switching = false


func _on_opponent_dialogue_finished(opponent: Node2D) -> void:
	if opponent.get(&"lost") == true:
		return
	# 新战斗场景自己管敌人，不需要旧的 combat_actor 场景
	var combatants: Array[PackedScene] = []
	start_combat(combatants)


func _on_battle_finished(player_won: bool) -> void:
	_switching = true
	remove_child(combat_screen)
	$AnimationPlayer.play_backwards(&"fade_to_black")
	if current_map != null and is_instance_valid(current_map):
		current_map.process_mode = Node.PROCESS_MODE_INHERIT
	var dialogue: Node = load("res://dialogue/dialogue_player/dialogue_player.tscn").instantiate()

	if player_won:
		dialogue.dialogue_file = PLAYER_WIN
	else:
		dialogue.dialogue_file = PLAYER_LOSE

	await $AnimationPlayer.animation_finished
	var player: Node2D = current_player()
	var ui: Node = current_dialogue_ui()
	if player != null and ui != null:
		ui.show_dialogue(player, dialogue)
	else:
		push_warning("[Game] 找不到当前地图里的玩家/对话入口，战后对话没起来")
	combat_screen.clear_combat()
	_switching = false
	await dialogue.dialogue_finished
	dialogue.queue_free()
#endregion
