extends Control
## B 系统：浮在角色头顶的对话框（头像 + 名字牌 + 正文 + 继续箭头）
## 数据格式：JSON 数组 [{ "speaker": "角色id", "text": "...", "expression": 0 }]
## speaker 为空 = 旁白。头像优先取 characters.json 的 avatar（表情 GIF），否则退回 portrait。

const CHAR_CONFIG_PATH := "res://dialogue/characters.json"
const TEXT_SPEED := 40.0
const SCREEN_MARGIN := 8.0

## 框相对角色头顶再往上的距离（屏幕像素）
@export var head_offset: float = 96.0
## 调查对话时，玩家走离触发对象超过此距离（世界像素）→ 自动结束对话
@export var leave_distance: float = 100.0

## 调试：直接指定对话文件，_ready 时自动显示（独立预览用）
@export_file("*.json") var debug_file: String = ""
@export var debug_screenshot: bool = false

@onready var _box: Panel = $DialogueBox
@onready var _avatar: TextureRect = $DialogueBox/Avatar
@onready var _name_plate: TextureRect = $DialogueBox/NamePlate
@onready var _name_label: Label = $DialogueBox/NamePlate/NameLabel
@onready var _text_label: RichTextLabel = $DialogueBox/TextLabel
@onready var _continue_hint: TextureRect = $DialogueBox/ContinueHint

var _char_configs: Dictionary = {}
var _lines: Array = []
var _index := 0
var _displayed := 0
var _display_timer := 0.0
var _is_displaying := false
var _is_completed := false
var _dialogue_node: Node = null
var _player: Pawn = null
var _actor: Node2D = null
var _lock_movement: bool = true


func _ready() -> void:
	visible = false
	_load_char_config()
	if debug_file != "":
		visible = true
		_load_file(debug_file)
		if _lines.size() > 0:
			_show_line()
		if debug_screenshot:
			_debug_shot()


func _debug_shot() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var img := get_viewport().get_texture().get_image()
	var dir := "res://debug_shots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	img.save_png(dir.path_join("quick_dialogue.png"))
	print("debug shot: quick_dialogue")


## 与 demo 的 interface.gd 同签名：grid.gd 调用 show_dialogue(pawn, dialogue_player)
func show_dialogue(player: Pawn, dialogue: Node) -> void:
	visible = true
	_player = player
	_dialogue_node = dialogue
	# 触发对话的角色/物体 = DialoguePlayer 的父节点（Node2D）
	var parent: Node = dialogue.get_parent()
	if parent is Node2D:
		_actor = parent
	elif player != null:
		_actor = player
	else:
		_actor = null
	# 差分：调查类（OBJECT）不锁移动（可边走边看），战前（ACTOR）锁死移动。
	# 将来若某行需要选项/确认，也会强制锁（见 _line_needs_lock）。
	_lock_movement = not (_actor is Pawn and _actor.type == Pawn.CellType.OBJECT)
	if player != null and _lock_movement:
		player.set_active(false)
	_index = 0
	_lines.clear()
	_load_file(dialogue.dialogue_file)
	if _lines.size() > 0:
		_show_line()


func _load_char_config() -> void:
	if not FileAccess.file_exists(CHAR_CONFIG_PATH):
		return
	var file := FileAccess.open(CHAR_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null or not data.has("characters"):
		return
	for id: String in data["characters"]:
		_char_configs[id] = data["characters"][id]


func _get_char(id: String) -> Dictionary:
	if _char_configs.has(id):
		return _char_configs[id]
	return {"name": id, "portrait": ""}


func _load_file(path: String) -> void:
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var raw := file.get_as_text()
	file.close()
	if path.get_extension().to_lower() == "json":
		var data: Variant = JSON.parse_string(raw)
		if data is Array:
			_lines = data
	else:
		_lines = _parse_scenario(raw)


## 剧本格式：每行 `[角色名]台词`（`[ ]` 或纯文本 = 旁白）；行首 `!` 表示该行锁死移动（时停）。
## 例：
##   [ ]只是一把钥匙……
##   [新火娘]捡起来看看！
##   ![文手]我试着捡起了钥匙！……但是太重了。
func _parse_scenario(text: String) -> Array:
	var out: Array = []
	for raw_line in text.split("\n"):
		var s := raw_line.strip_edges()
		if s.is_empty() or s.begins_with("#"):
			continue
		var lock := false
		if s.begins_with("!"):
			lock = true
			s = s.substr(1).strip_edges()
		var speaker := ""
		var body := s
		if s.begins_with("["):
			var end := s.find("]")
			if end > 0:
				speaker = _resolve_speaker(s.substr(1, end - 1).strip_edges())
				body = s.substr(end + 1).strip_edges()
		var line := {"speaker": speaker, "text": body}
		if lock:
			line["lock"] = true
		out.append(line)
	return out


## 把剧本里的角色名 / 别名 / id 解析成角色 id；空名 = 旁白。
func _resolve_speaker(raw_name: String) -> String:
	if raw_name.is_empty():
		return ""
	if _char_configs.has(raw_name):
		return raw_name
	for id: String in _char_configs:
		var cfg: Dictionary = _char_configs[id]
		if str(cfg.get("name", "")) == raw_name:
			return id
		var aliases: Variant = cfg.get("aliases", [])
		if aliases is Array and (aliases as Array).has(raw_name):
			return id
	return raw_name


func _process(delta: float) -> void:
	if not visible:
		return
	_update_box_position()
	# 不锁移动的调查对话：玩家走远则自动结束
	if not _lock_movement:
		_check_leave()
	if _is_displaying and not _is_completed:
		_display_timer += delta
		var target := int(_display_timer * TEXT_SPEED)
		if target > _displayed:
			_displayed = target
			_text_label.visible_characters = _displayed
			if _displayed >= _text_label.get_total_character_count():
				_is_completed = true
				_continue_hint.visible = true


## 把对话框浮到触发角色头顶（世界坐标 → 屏幕坐标，含 Camera2D）
func _update_box_position() -> void:
	var view_size := get_viewport_rect().size
	var target_pos: Vector2
	if _actor != null and is_instance_valid(_actor):
		var screen_pos: Vector2 = get_viewport().get_canvas_transform() * _actor.global_position
		target_pos = screen_pos - Vector2(_box.size.x * 0.5, _box.size.y + head_offset)
	else:
		target_pos = Vector2((view_size.x - _box.size.x) * 0.5, view_size.y * 0.5 - _box.size.y)
	target_pos.x = clampf(target_pos.x, SCREEN_MARGIN, view_size.x - _box.size.x - SCREEN_MARGIN)
	target_pos.y = clampf(target_pos.y, SCREEN_MARGIN, view_size.y - _box.size.y - SCREEN_MARGIN)
	_box.position = target_pos


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_handle_advance()
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_advance()
		get_viewport().set_input_as_handled()
		return
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		_handle_advance()
		get_viewport().set_input_as_handled()
		return


func _handle_advance() -> void:
	if _is_displaying and not _is_completed:
		_complete_text()
	elif _is_completed:
		_advance()


## 玩家离开触发对象 → 结束对话（仅用于不锁移动的调查对话）
func _check_leave() -> void:
	if _player == null or _actor == null or not is_instance_valid(_player) or not is_instance_valid(_actor):
		return
	if _player.global_position.distance_to(_actor.global_position) > leave_distance:
		_finish()


func _complete_text() -> void:
	_displayed = _text_label.get_total_character_count()
	_text_label.visible_characters = -1
	_is_completed = true
	_continue_hint.visible = true


func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		_finish()
		return
	_show_line()


func _finish() -> void:
	visible = false
	if _player != null:
		_player.set_active(true)
	if _dialogue_node != null and _dialogue_node.has_signal(&"dialogue_finished"):
		_dialogue_node.dialogue_finished.emit()


## 该行是否需要锁死移动（含选项/确认字段时为真）。
func _line_needs_lock(line: Dictionary) -> bool:
	if bool(line.get("lock", false)):
		return true
	var opts: Variant = line.get("options", null)
	return opts is Array and (opts as Array).size() > 0


func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	var speaker: String = str(line.get("speaker", ""))
	var text: String = str(line.get("text", ""))
	var display_name: String = str(line.get("display_name", ""))

	# 若该行需要选项/确认，则临时锁死移动
	if _line_needs_lock(line) and _player != null:
		_lock_movement = true
		_player.set_active(false)

	var cfg: Dictionary = _get_char(speaker)
	if speaker == "":
		_name_plate.visible = false
		_avatar.visible = false
	else:
		_name_plate.visible = true
		_name_label.text = display_name if display_name != "" else str(cfg.get("name", speaker))
		var avatar_path: String = str(cfg.get("avatar", ""))
		if avatar_path.is_empty():
			avatar_path = str(cfg.get("portrait", ""))
		if not avatar_path.is_empty() and ResourceLoader.exists(avatar_path):
			_avatar.texture = load(avatar_path)
			_avatar.visible = true
		else:
			_avatar.visible = false

	_text_label.text = text
	_text_label.visible_characters = 0
	_displayed = 0
	_display_timer = 0.0
	_is_displaying = true
	_is_completed = false
	_continue_hint.visible = false
	_update_box_position()
