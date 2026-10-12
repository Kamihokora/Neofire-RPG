extends Control
## B 系统：版图内/战斗内小框对话（头像 + 名字牌 + 正文 + 继续箭头）
## 数据格式：JSON 数组 [{ "speaker": "角色id", "text": "...", "expression": 0 }]
## speaker 为空 = 旁白。头像取自 characters.json 的 portrait（立绘缩略）。

const CHAR_CONFIG_PATH := "res://dialogue/characters.json"
const TEXT_SPEED := 40.0

## 调试：直接指定对话文件，_ready 时自动显示（独立预览用）
@export_file("*.json") var debug_file: String = ""
@export var debug_screenshot: bool = false

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
	if player != null:
		player.set_active(false)  # 冻结玩家移动
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
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Array:
		_lines = data


func _process(delta: float) -> void:
	if _is_displaying and not _is_completed:
		_display_timer += delta
		var target := int(_display_timer * TEXT_SPEED)
		if target > _displayed:
			_displayed = target
			_text_label.visible_characters = _displayed
			if _displayed >= _text_label.get_total_character_count():
				_is_completed = true
				_continue_hint.visible = true


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


func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	var speaker: String = str(line.get("speaker", ""))
	var text: String = str(line.get("text", ""))
	var display_name: String = str(line.get("display_name", ""))

	# 头像 + 名字
	var cfg: Dictionary = _get_char(speaker)
	if speaker == "":
		_name_plate.visible = false
		_avatar.visible = false
	else:
		_name_plate.visible = true
		_name_label.text = display_name if display_name != "" else str(cfg.get("name", speaker))
		var portrait: String = str(cfg.get("portrait", ""))
		if portrait != "" and ResourceLoader.exists(portrait):
			_avatar.texture = load(portrait)
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
