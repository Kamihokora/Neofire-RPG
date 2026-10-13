extends Node
## B 系统：对话驱动器（游戏侧）。
##
## 剧本/角色/分支交给 Dialogic（.dtl 纯文本，一样好手改），
## 这里只管游戏侧规则：谁锁移动、玩家走开怎么办、什么时候算结束。
##
## 旧版 quick_dialogue.gd 的 JSON + 剧本解析已退休；外观搬到了
## dialogue/dialogic/layout/neofire_box.gd（Dialogic 自定义 layout）。

signal dialogue_started
signal dialogue_finished

## 剧本文件（Dialogic 时间线，纯文本，可直接手改）
@export_file("*.dtl") var dialogue_file: String
## 用哪套 Dialogic 样式：留空 = 默认（气泡跟头顶）；填路径 = 那套（方案A 全屏立绘用 neofire_story_style）
@export_file("*.tres") var style: String = ""
## 兼容旧字段（界面标题用）
@export var dialogue_name: String = ""
## 调查类对话：玩家走离触发对象超过这个距离就结束 / 触发离开反应（0 = 不检测）
@export var leave_distance: float = 100.0
## 队内角色正在说话时玩家走开 → 跳到剧本里的 leave_<n> 标签（不结束）
@export var leave_reactions: bool = true

@export_group("相机")
## 调查类对话（走近按 E 看东西）时把相机拉近到这个缩放；留 (0,0) = 不动相机
@export var investigate_zoom: Vector2 = Vector2(1.7, 1.7)
@export var zoom_on_investigate: bool = true

## 跨对话持久的“离开计数”（按剧本路径记）
static var _global_leave_counts: Dictionary = {}

var leave_count: int = 0

var _player: Node2D = null
var _actor: Node2D = null
var _lock_movement: bool = true
var _active: bool = false
var _is_investigation: bool = false
var _zoom_pushed: bool = false
var _current_character: DialogicCharacter = null
var _labels: PackedStringArray = PackedStringArray()
## 已经在播“离开反应”了：别再重复触发（否则玩家在反应期间还站在外面，会每帧跳一次）
var _reacting: bool = false


func _ready() -> void:
	_register_character_aliases()
	Dialogic.signal_event.connect(_on_signal_event)
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	Dialogic.Text.speaker_updated.connect(_on_speaker_updated)


## 让剧本里可以直接用中文名/别名说话（`焰铃: ...` / `新火娘: ...`）。
## Dialogic 只能用目录键（= 文件名 xinhuo）找角色，而那个目录是编辑器维护的、
## 会把我们自己加的别名清掉，所以在运行时补一份。
func _register_character_aliases() -> void:
	var directory: Dictionary = DialogicResourceUtil.get_character_directory()
	var extra: Dictionary = {}
	for key: Variant in directory:
		var path: Variant = directory[key]
		if typeof(path) != TYPE_STRING or not ResourceLoader.exists(path):
			continue
		var character := load(path) as DialogicCharacter
		if character == null:
			continue
		var names: Array = [character.display_name]
		names.append_array(character.nicknames)
		for n: String in names:
			if not n.is_empty() and not directory.has(n):
				extra[n] = path
	for n: Variant in extra:
		directory[n] = extra[n]


## 由 DialogueUI.show_dialogue() 调用（grid.gd / game.gd 的入口）
func start_dialogue_with(player: Node2D) -> void:
	_player = player
	var parent: Node = get_parent()
	_actor = parent if parent is Node2D else null
	if _actor == null:
		_actor = player
	# 差分：调查类（OBJECT）不锁移动（可边走边看），战前（ACTOR）锁死移动
	_is_investigation = _actor is Pawn and _actor.type == Pawn.CellType.OBJECT
	_lock_movement = not _is_investigation
	_push_investigate_zoom()

	leave_count = int(_global_leave_counts.get(dialogue_file, 0))
	_current_character = null
	_reacting = false
	_labels = _scan_labels()

	var timeline: DialogicTimeline = _load_timeline()
	if timeline == null:
		push_error("[DialoguePlayer] 载入剧本失败：%s" % dialogue_file)
		dialogue_started.emit()
		_finish()
		return

	_active = true
	dialogue_started.emit()
	# 每段对话都显式定样式：留空就回默认（气泡跟头顶）。
	# 不然上一段用了方案A，这段会跟着用方案A。
	var target_style := style if not style.is_empty() else DialogicStylesUtil.get_default_style_path()
	if Dialogic.Styles.get_current_style() != target_style.get_file().get_basename():
		Dialogic.Styles.change_style(target_style)
		# 必须等新 layout ready 再 start：否则 Dialogic.start() 会在 ready 时挂 clear()，
		# 把 base_style 清成 ""，紧接着第一个文本事件就把样式切回默认样式（实测踩到过）。
		var new_layout: Node = Dialogic.Styles.get_layout_node()
		if new_layout != null and not new_layout.is_node_ready():
			await new_layout.ready
	Dialogic.start(timeline)
	_bind_layout()
	_set_player_active(not _lock_movement)


func _process(_delta: float) -> void:
	if not _active or _lock_movement or _reacting or leave_distance <= 0.0:
		return
	if _player == null or _actor == null:
		return
	if not is_instance_valid(_player) or not is_instance_valid(_actor):
		return
	if _player.global_position.distance_to(_actor.global_position) > leave_distance:
		_on_player_left()


func _load_timeline() -> DialogicTimeline:
	if dialogue_file.is_empty() or not ResourceLoader.exists(dialogue_file):
		return null
	return load(dialogue_file) as DialogicTimeline


#region Dialogic 接线
################################################################################

## 把角色绑到场上节点：队内角色 → 主角头顶；其它（敌人/物件/旁白）→ 触发对象头顶
func _bind_layout() -> void:
	var layout: Node = Dialogic.Styles.get_layout_node()
	if layout == null or not layout.has_method(&"register_character"):
		# 方案A（全屏立绘）这类样式没有"气泡跟头顶"，不需要登记
		return
	layout.clear_registrations()
	layout.set_default_actor(_actor)
	for path: String in _character_paths():
		var character := load(path) as DialogicCharacter
		if character == null:
			continue
		if bool(character.custom_info.get("party", false)) and _player != null:
			layout.register_character(character, _player)
		else:
			layout.register_character(character, _actor)


## 工程里所有角色资源（Dialogic 的角色目录）
func _character_paths() -> Array:
	var out: Array = []
	for key: Variant in DialogicResourceUtil.get_character_directory():
		var path: Variant = DialogicResourceUtil.get_character_directory()[key]
		if typeof(path) == TYPE_STRING and not out.has(path):
			out.append(path)
	return out


func _on_speaker_updated(character: DialogicCharacter) -> void:
	_current_character = character


## 剧本里的 [signal arg="lock"/"unlock"] —— 单行时停
## [signal arg="transfer:trial/SpawnFromMain"] —— 事件转移（换地图 + 落点，RPG Maker 式）
## [signal arg="goto:res://x.tscn"] —— 老写法：按路径直接切场景（不带落点）
func _on_signal_event(argument: Variant) -> void:
	if not _active:
		return
	var arg := str(argument).strip_edges()
	if arg.begins_with("transfer:") or arg.begins_with("goto:"):
		_transfer_to(arg.trim_prefix("transfer:").trim_prefix("goto:"))
		return
	match arg:
		"lock":
			_set_player_active(false)
		"unlock":
			_set_player_active(true)


## 事件转移：先按正常流程把这段对话收场（关框/解锁玩家），再请求换地图。
## 注意不能一边让 Dialogic 执行事件、一边同步 end_timeline()——所以延后一帧。
func _transfer_to(target: String) -> void:
	if MapSystem.parse_target(target).is_empty():
		push_error("[DialoguePlayer] 转移目标无效：'%s'（剧本里写 transfer:地图id/落点id）" % target)
		return
	_finish_revealing_text()
	call_deferred(&"_end_timeline")
	MapSystem.request(target)


func _on_timeline_ended() -> void:
	if _active:
		_finish()


## 玩家走开：队内角色正在说话 → 跳到 leave_<n> 反应；否则直接结束
func _on_player_left() -> void:
	leave_count += 1
	_global_leave_counts[dialogue_file] = leave_count
	var tier := _pick_leave_tier(leave_count)
	if leave_reactions and tier > 0 and _speaker_is_party() and _has_label("leave_%d" % tier):
		_reacting = true
		Dialogic.Jump.jump_to_label("leave_%d" % tier)
		# 当前那一行还在等输入，光跳标签不会立刻生效；手动推进到标签处
		Dialogic.handle_next_event()
		return
	_end_timeline()


func _speaker_is_party() -> bool:
	if _current_character == null:
		return false
	return bool(_current_character.custom_info.get("party", false))


## 剧本里存在的最大的 n（n <= count），对应 @leave n
func _pick_leave_tier(count: int) -> int:
	var best := 0
	for label: String in _labels:
		if not label.begins_with("leave_"):
			continue
		var raw := label.trim_prefix("leave_")
		if raw.is_valid_int() and int(raw) <= count and int(raw) > best:
			best = int(raw)
	return best


func _has_label(label: String) -> bool:
	return _labels.has(label)


## 剧本是纯文本，直接扫 label 行（Dialogic 的 label 缓存只在编辑器里可用）
func _scan_labels() -> PackedStringArray:
	var out := PackedStringArray()
	if dialogue_file.is_empty() or not FileAccess.file_exists(dialogue_file):
		return out
	var f := FileAccess.open(dialogue_file, FileAccess.READ)
	if f == null:
		return out
	for line in f.get_as_text().split("\n"):
		var s := line.strip_edges()
		if s.begins_with("label "):
			out.append(s.substr(6).strip_edges().split(" ")[0])
	f.close()
	return out
#endregion


#region 收场
################################################################################

## 调查对话：把相机拉近一点（复用主角的缩放栈，key = "investigate"）
func _push_investigate_zoom() -> void:
	if not zoom_on_investigate or investigate_zoom == Vector2.ZERO:
		return
	var avatar := _player as ActorPlayer
	if avatar == null:
		return
	avatar.request_zoom(&"investigate", investigate_zoom)
	_zoom_pushed = true


## 调查对话结束/被打断：收回缩放（自动回到上一层请求或房间默认值）
func _pop_investigate_zoom() -> void:
	if not _zoom_pushed:
		return
	_zoom_pushed = false
	var avatar := _player as ActorPlayer
	if avatar != null and is_instance_valid(avatar):
		avatar.release_zoom(&"investigate")


func _set_player_active(value: bool) -> void:
	if _player != null and is_instance_valid(_player):
		_player.set_active(value)


## 安全结束时间线：先把正在打字的文本收尾。
## 原因：Dialogic 的 event_text.gd 在打到"最后一段"时会调 Choices.is_question(current_event_idx)，
## 而时间线一旦结束 current_event_idx 就是 -1 → is_question(-1) 去读 current_timeline_events[-1]
## → 报 "Out of bounds get index '-1'"（Dialogic 那边没做负索引保护）。
func _end_timeline() -> void:
	_finish_revealing_text()
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline()


func _finish_revealing_text() -> void:
	for node: Node in get_tree().get_nodes_in_group("dialogic_dialog_text"):
		if node.has_method(&"finish_text"):
			node.finish_text(true)


func _finish() -> void:
	_active = false
	_pop_investigate_zoom()
	_set_player_active(true)
	dialogue_finished.emit()
#endregion
