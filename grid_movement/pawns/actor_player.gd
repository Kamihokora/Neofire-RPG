@tool
class_name ActorPlayer
extends CharacterBody2D
## 自由移动（横版/Soul Knight 式）的主角。
##
## 取代原来的格子移动 Walker：用 CharacterBody2D + move_and_slide，
## 碰撞来自「Walls」那层（由 grid_movement/grid/walls.gd 从地图生成）。
##
## 行走图：Actor1.png 总图版 —— 横向 4 个角色、纵向 2 个角色（共 8 个），
## 每个角色块是 3 列 × 4 行、每格 48×48（4 向 × 3 帧）。
## 换角色只要改 character_index；图版不是这个排布就改 sheet_columns/sheet_rows。

signal interact_available(target: Node)
signal interacted(target: Node)

## 队长足迹的采样间距（队友按这个间距跟）
const TRAIL_SAMPLE := 8.0        # 队长每走这么多像素记一个足迹点（与 ActorNpc 一致）

@export_group("移动")
@export var speed: float = 220.0
@export var sprint_multiplier: float = 1.6
## 走路动画速度（帧/秒）
@export var walk_fps: float = 8.0

@export_group("行走图")
## 用图版里第几个角色（0 起，按「先横后纵」排列）
@export var character_index: int = 0

@export_group("交互")
## 走到多近可以按 E 交谈（像素）
@export var talk_range: float = 96.0
## 交互键（不走 InputMap，避免编辑器回写 project.godot 时丢掉）
@export var interact_keys: Array[int] = [KEY_E, KEY_F]
@export var interact_joy_button: int = 1

@export_group("相机")
@export var camera_follow: bool = true
## 这张地图的**默认缩放**（想不同房间不同手感，就在那个房间的 Player 实例上改这一项）
@export var camera_zoom: Vector2 = Vector2(1.5, 1.5)
## 缩放过渡时长（秒）；0 = 直接跳
@export var zoom_duration: float = 0.25

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _camera: Camera2D = $Camera
@onready var _hint: Label = $Hint

## 兼容旧 Pawn 的接口：active = false 表示锁住移动（对话期间）
var active: bool = true:
	set(value):
		active = value
		if not value:
			velocity = Vector2.ZERO
			_play_idle()
			if _hint != null:
				_hint.visible = false

var _facing: Vector2i = Vector2i.DOWN
var _dialogue_ui: Node = null
var _interact_target: Node = null
var _interact_held := false
## 缩放请求栈：key → 缩放值。谁后请求谁生效（调查对话 / 远瞰判定区都往这里丢）
var _zoom_requests: Dictionary = {}
var _zoom_order: Array[StringName] = []
var _zoom_tween: Tween = null


func _ready() -> void:
	# 编辑器里不建帧/不抢相机（行走图是运行时切的，编辑器里用占位框看位置）
	if Engine.is_editor_hint():
		queue_redraw()
		return
	_build_frames()
	_camera.enabled = camera_follow
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	_camera.zoom = camera_zoom          # 每个房间可以有不同的默认缩放
	_camera.add_to_group(&"player_camera")          # Walls 用它设地图边界
	# 相机一定要自己抢 current：地图场景/外壳里若还留着别的 Camera2D，
	# 谁后进树谁就成了当前相机（表现就是"画面钉死、相机不跟人走"）
	if camera_follow:
		_camera.make_current()
	add_to_group(&"player")                          # 队友/敌人靠这个组找队长和玩家
	_trail.append(global_position)
	interact_available.connect(_on_interact_available)
	_play_idle()
	# 事件转移的落点要等队友都 _ready 完（队友要按落点排队），所以延后一帧
	_apply_map_spawn.call_deferred()


## 从总图版切出 4 向 × 3 帧（切图逻辑在 ActorSheet 里，队友/敌人共用）
func _build_frames() -> void:
	_sprite.sprite_frames = ActorSheet.build_frames(character_index, walk_fps)


## 编辑器占位框（玩家也是运行时切图，编辑器里看不到；还有个“从这里出发”的标记）
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var half := ActorSheet.FRAME_SIZE * 0.5
	var rect := Rect2(Vector2(-half, -half), Vector2(ActorSheet.FRAME_SIZE, ActorSheet.FRAME_SIZE))
	draw_rect(rect, Color(1.0, 0.85, 0.35, 0.22), true)
	draw_rect(rect, Color(1.0, 0.9, 0.45, 0.95), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-half, -half - 4.0),
		"玩家", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(1.0, 0.95, 0.7))


func _anim_name(dir: Vector2i, kind: String) -> StringName:
	return ActorSheet.anim_name(dir, kind)


#region 移动
################################################################################

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not active:
		velocity = Vector2.ZERO
		_play_idle()
		move_and_slide()
		return

	var dir := Vector2(
		Input.get_axis(&"move_left", &"move_right"),
		Input.get_axis(&"move_up", &"move_down"))
	velocity = dir.normalized() * movement_speed()
	move_and_slide()

	_record_trail()
	if dir.length() > 0.1:
		_facing = _direction_from_vector(dir)
		if _sprite.animation != _anim_name(_facing, "walk"):
			_sprite.play(_anim_name(_facing, "walk"))
	else:
		_play_idle()

	_update_interact_target()
	_poll_interact()


func _direction_from_vector(dir: Vector2) -> Vector2i:
	return ActorSheet.direction_from_vector(dir)


func movement_speed() -> float:
	return speed * (sprint_multiplier if bool(RunState.instance.global_flags.get("can_sprint", false)) and Input.is_key_pressed(KEY_SHIFT) else 1.0)


func _play_idle() -> void:
	var anim := _anim_name(_facing, "idle")
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)
#endregion


#region 相机缩放（可复用：调查对话拉近 / 判定区远瞰）
################################################################################

## 请求一个缩放（key 随便起，比如 "investigate" / "overlook"）。
## 可以同时有多份请求（走进判定区的同时又开了调查对话）：最后请求的那个生效。
func request_zoom(key: StringName, target: Vector2) -> void:
	_zoom_order.erase(key)
	_zoom_order.append(key)
	_zoom_requests[key] = target
	_apply_zoom()


## 收回某个请求（对话结束 / 走出判定区）：还会自动回到上一层请求或默认缩放
func release_zoom(key: StringName) -> void:
	if not _zoom_requests.has(key):
		return
	_zoom_requests.erase(key)
	_zoom_order.erase(key)
	_apply_zoom()


## 清空所有缩放请求，回到这张地图的默认缩放
func reset_zoom() -> void:
	_zoom_requests.clear()
	_zoom_order.clear()
	_apply_zoom()


func current_zoom_target() -> Vector2:
	if not _zoom_order.is_empty():
		return _zoom_requests[_zoom_order[_zoom_order.size() - 1]]
	return camera_zoom


func _apply_zoom() -> void:
	if _camera == null:
		return
	var target := current_zoom_target()
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	if zoom_duration <= 0.0:
		_camera.zoom = target
		return
	_zoom_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_zoom_tween.tween_property(_camera, ^"zoom", target, zoom_duration)
#endregion


#region 交互（自由移动下不再"撞格子触发"，改成走近 + 按键）
################################################################################

## 场景里所有能交谈的东西：带 DialoguePlayer 子节点、且在 interactable 组里
func _nearby_interactables() -> Array[Node]:
	var out: Array[Node] = []
	for node: Node in get_tree().get_nodes_in_group(&"interactable"):
		if node is Node2D and is_instance_valid(node) and node.is_visible_in_tree() and (node.has_node(^"DialoguePlayer") or node.has_method(&"interact_with")):
			out.append(node)
	return out


func _update_interact_target() -> void:
	# 对话进行中：不再选目标（提示自动收起），按 E 也不会重开
	if _dialogue_busy():
		if _interact_target != null:
			_interact_target = null
			interact_available.emit(null)
		return
	var best: Node = null
	var best_dist := talk_range
	for node: Node in _nearby_interactables():
		var d: float = global_position.distance_to((node as Node2D).global_position)
		if d <= best_dist:
			best_dist = d
			best = node
	if best != _interact_target:
		_interact_target = best
		interact_available.emit(best)


## 交互按键用轮询而不是 _unhandled_input：
## 事件管线里别的 UI/插件可能把按键吃掉（实测按 E 没反应），轮询与焦点无关，最稳。
func _poll_interact() -> void:
	var down := false
	for keycode: int in interact_keys:
		if Input.is_key_pressed(keycode):
			down = true
			break
	if not down and Input.is_joy_button_pressed(0, interact_joy_button):
		down = true
	if down and not _interact_held:
		_interact_held = true
		_try_interact()
	elif not down:
		_interact_held = false


## 正在播对话吗
func _dialogue_busy() -> bool:
	var ui := _dialogue_ui_node()
	return ui != null and ui.has_method(&"is_busy") and ui.is_busy()


func _try_interact() -> void:
	if not active or _interact_target == null or _dialogue_busy():
		return
	var target := _interact_target
	if target.has_method(&"interact_with"):
		if target.interact_with(self): interacted.emit(target)
		return
	var ui := _dialogue_ui_node()
	if ui == null:
		push_warning("[ActorPlayer] 场景里找不到 DialogueUI（对话入口），按 E 不会有反应")
		return
	if ui.has_method(&"show_dialogue"):
		interacted.emit(target)
		ui.show_dialogue(self, target.get_node(^"DialoguePlayer"))


## 懒查找对话入口：主角的 _ready 比 DialogueUI 早跑（同级兄弟按顺序），
## 在 _ready 里缓存会拿到 null → 按 E 静默失效（踩过）。这里按需再找一次。
func _dialogue_ui_node() -> Node:
	if _dialogue_ui == null or not is_instance_valid(_dialogue_ui):
		_dialogue_ui = get_tree().get_first_node_in_group(&"dialogue_ui")
	return _dialogue_ui


## 交互目标变化时刷新"E 交谈"提示
func _on_interact_available(target: Node) -> void:
	if _hint != null:
		_hint.visible = target != null and active


## 兼容旧 Pawn 的接口：DialoguePlayer 用 set_active 锁/解锁移动
func set_active(value: bool) -> void:
	active = value


## 语义更清楚的别名
func set_locked(value: bool) -> void:
	active = not value


func current_cell_size() -> int:
	return ActorSheet.FRAME_SIZE


#region 事件转移（RPG Maker 的"场所移动"落点）
################################################################################

## 我属于哪张地图（跟着 owner 链往上走：Player→Exploration→Game）
func map_root() -> Node:
	var node: Node = self
	while node.owner != null:
		node = node.owner
	return node


## 新地图进场时取 MapSystem 留下的落点请求，站到对应 MapSpawn 上
func _apply_map_spawn() -> void:
	if not MapSystem.has_pending():
		return
	var want := MapSystem.consume_spawn()
	var marker := MapSpawn.find(want, map_root())
	if marker == null:
		push_warning("[ActorPlayer] 本地图里找不到落点：%s" % [want if not want.is_empty() else "默认落点"])
		return
	land_at(marker.global_position, marker.facing)


## 落到某点：玩家定位、队友在身后排成一列、足迹重铺
## （队友靠 trail_point 找位置，所以要用一条"朝后的直线足迹"把队形铺出来）
func land_at(pos: Vector2, facing: Vector2i = Vector2i.DOWN) -> void:
	global_position = pos
	_facing = facing
	_play_idle()
	velocity = Vector2.ZERO
	var back := -Vector2(facing).normalized()
	if back.length() < 0.01:
		back = Vector2.UP
	_trail.clear()
	for i in 80:
		_trail.append(pos + back * float(i) * TRAIL_SAMPLE)
	var scope := map_root()
	for node: Node in get_tree().get_nodes_in_group(&"party_follower"):
		var npc := node as ActorNpc
		if npc == null or not scope.is_ancestor_of(npc):
			continue
		npc.global_position = trail_point(npc.party_index)
#endregion


#region 队长足迹（队友按 RPG Maker 的方式跟着走）
################################################################################

var _trail: PackedVector2Array = PackedVector2Array()


func capture_travel_state() -> Dictionary:
	var scope := map_root() as Node2D
	var point := scope.to_local(global_position)
	var trail: Array = []
	for sample: Vector2 in _trail:
		var local := scope.to_local(sample)
		trail.append([local.x, local.y])
	return {"position": [point.x, point.y], "facing": [_facing.x, _facing.y], "trail": trail}


func restore_travel_state(data: Dictionary) -> void:
	var scope := map_root() as Node2D
	var point: Array = data["position"]
	var facing: Array = data["facing"]
	land_at(scope.to_global(Vector2(float(point[0]), float(point[1]))), Vector2i(int(facing[0]), int(facing[1])))
	var trail: Array = data.get("trail", [])
	if not trail.is_empty():
		_trail.clear()
		for sample: Array in trail:
			_trail.append(scope.to_global(Vector2(float(sample[0]), float(sample[1]))))
	for node: Node in get_tree().get_nodes_in_group(&"party_follower"):
		if scope.is_ancestor_of(node) and node is ActorNpc:
			node.global_position = trail_point(node.party_index)
	_interact_held = false
	_interact_target = null
	_hint.hide()
	active = true
	_camera.reset_smoothing()


func _record_trail() -> void:
	if _trail.is_empty() or _trail[0].distance_to(global_position) >= TRAIL_SAMPLE:
		_trail.insert(0, global_position)
		if _trail.size() > 600:
			_trail.resize(ActorNpc.TRAIL_MAX)


## 第 index 个跟随者（0 = 紧跟队长身后）该站的位置：沿足迹往回数
func trail_point(index: int) -> Vector2:
	if _trail.is_empty():
		return global_position
	var spacing: float = 44.0
	var followers := get_tree().get_nodes_in_group(&"party_follower")
	if followers.size() > index and followers[index] is ActorNpc:
		spacing = (followers[index] as ActorNpc).follow_spacing
	var steps := int(round((float(index + 1) * spacing) / TRAIL_SAMPLE))
	if steps < _trail.size():
		return _trail[steps]
	# 足迹还不够长（刚开局/刚传送）：沿最老那一段的延长线往外推，
	# 否则所有队友的目标都被 clamp 到同一个点 → 全挤在队长身上。
	var last: Vector2 = _trail[_trail.size() - 1]
	var prev: Vector2 = _trail[maxi(_trail.size() - 2, 0)]
	var dir := last - prev
	if dir.length() < 0.01:
		dir = Vector2.DOWN
	return last + dir.normalized() * float(steps - (_trail.size() - 1)) * TRAIL_SAMPLE
#endregion
#endregion
