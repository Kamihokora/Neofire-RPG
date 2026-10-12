extends Control
## A 系统：全屏剧情对话（纯逻辑层）
## UI 结构与布局全部在 test_story_dialogue.tscn 里，可在编辑器手动调整。

signal dialogue_finished

const CHAR_CONFIG_PATH := "res://dialogue/characters.json"
const TEXT_SPEED := 40.0
## 非说话角色立绘的不透明度（有背景时不至于像幽灵）
const INACTIVE_ALPHA := 0.7

@export_file("*.json") var dialogue_file: String = "res://dialogue/dialogue_data/test_story.json"
## 调试：运行时自动截图到 res://debug_shots/（供 agent 检查画面）
@export var debug_screenshot: bool = false

@onready var _name_plate: TextureRect = $DialogueBox/NamePlate
@onready var _name_label: Label = $DialogueBox/NamePlate/NameLabel
@onready var _text_label: RichTextLabel = $DialogueBox/TextLabel
@onready var _continue_hint: TextureRect = $DialogueBox/ContinueHint
@onready var _portraits: Array = [$PortraitLayer/Portrait1, $PortraitLayer/Portrait2, $PortraitLayer/Portrait3]

var _char_configs: Dictionary = {}
var _narrator_color := Color(0.8, 0.8, 0.8)
var _lines: Array = []
var _index := 0
var _displayed := 0
var _display_timer := 0.0
var _is_displaying := false
var _is_completed := false


func _ready() -> void:
	_load_char_config()
	_load_dialogue()
	_continue_hint.visible = false
	if _lines.size() > 0:
		_show_line()
	if debug_screenshot:
		_capture_debug_shot()


func _capture_debug_shot() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	_save_shot("story_1")
	_complete_text()
	_advance()
	await get_tree().create_timer(0.8).timeout
	_save_shot("story_2")
	_advance()
	await get_tree().create_timer(0.8).timeout
	_save_shot("story_3")


func _save_shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var dir := "res://debug_shots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	img.save_png(dir.path_join(shot_name + ".png"))
	print("debug shot: ", shot_name)


# ---------------------------------------------------------------- 资源加载

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
	if data.has("narrator_color"):
		_narrator_color = Color.from_string(str(data["narrator_color"]), _narrator_color)
	for id: String in data["characters"]:
		_char_configs[id] = data["characters"][id]


func _get_char(id: String) -> Dictionary:
	if _char_configs.has(id):
		return _char_configs[id]
	return {"name": id, "name_color": "#ffffff", "portrait": ""}


func _load_dialogue() -> void:
	if not FileAccess.file_exists(dialogue_file):
		return
	var file := FileAccess.open(dialogue_file, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Array:
		_lines = data


# ---------------------------------------------------------------- 对话流程

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
		dialogue_finished.emit()
		return
	_show_line()


func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	var speaker: String = str(line.get("speaker", ""))
	var text: String = str(line.get("text", ""))
	var display_name: String = str(line.get("display_name", ""))

	if speaker == "":
		_name_plate.visible = false
	else:
		_name_plate.visible = true
		var cfg: Dictionary = _get_char(speaker)
		_name_label.text = display_name if display_name != "" else str(cfg.get("name", speaker))
		# 名字牌本身是红色，名字文字统一白色 + 深色描边（见 .tscn）

	_text_label.text = text
	_text_label.visible_characters = 0
	_displayed = 0
	_display_timer = 0.0
	_is_displaying = true
	_is_completed = false
	_continue_hint.visible = false
	_update_portraits(speaker, line.get("cast", []))


## 立绘槽位映射：单人用 Portrait1，双人用 Portrait2(左)+Portrait3(右)。
## 每个槽位的位置与大小在 .tscn 里手动配置（代码不覆盖）。
const PORTRAIT_SLOTS := {
	1: [0],
	2: [1, 2],
	3: [0, 1, 2],
}

func _update_portraits(speaker: String, cast: Array) -> void:
	var ids: Array = cast.duplicate()
	if ids.is_empty() and speaker != "":
		ids = [speaker]
	var count := mini(ids.size(), _portraits.size())
	for p: TextureRect in _portraits:
		p.visible = false
	var slots: Array = PORTRAIT_SLOTS.get(count, [0])
	for k in mini(slots.size(), ids.size()):
		var p: TextureRect = _portraits[slots[k]]
		var id: String = str(ids[k])
		var cfg: Dictionary = _get_char(id)
		var portrait_path: String = str(cfg.get("portrait", ""))
		if portrait_path != "" and ResourceLoader.exists(portrait_path):
			p.texture = load(portrait_path)
			p.visible = true
			p.modulate = Color(1, 1, 1, 1.0 if id == speaker else INACTIVE_ALPHA)


# ---------------------------------------------------------------- 对话特效（可被外部调用）

## 轻微跳动：表示兴奋、惊讶。node 省略则作用于继续箭头。
func effect_bounce(node: CanvasItem = null, times: int = 2, amount: float = 14.0, step: float = 0.11) -> void:
	var target: CanvasItem = node if node != null else _continue_hint
	if target == null:
		return
	var base_y: float = target.position.y
	var tween := create_tween()
	for _i in times:
		tween.tween_property(target, "position:y", base_y - amount, step).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(target, "position:y", base_y, step).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## 滑动渐入：剧情系统/立绘平滑进入画面。from: left/right/top/bottom。省略 node 则作用于整个界面。
func effect_slide_in(node: CanvasItem = null, from: String = "bottom", distance: float = 180.0, duration: float = 0.45) -> void:
	var target: CanvasItem = node if node != null else self
	if target == null:
		return
	var base_pos: Vector2 = target.position
	target.position = base_pos + _dir_offset(from, distance)
	target.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(target, "position", base_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "modulate:a", 1.0, duration)


## 滑动渐出：反向于 effect_slide_in。
func effect_slide_out(node: CanvasItem = null, to: String = "bottom", distance: float = 180.0, duration: float = 0.35) -> void:
	var target: CanvasItem = node if node != null else self
	if target == null:
		return
	var base_pos: Vector2 = target.position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(target, "position", base_pos + _dir_offset(to, distance), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(target, "modulate:a", 0.0, duration)
	await tween.finished
	target.position = base_pos


func _dir_offset(dir: String, distance: float) -> Vector2:
	match dir:
		"left":
			return Vector2(-distance, 0)
		"right":
			return Vector2(distance, 0)
		"top":
			return Vector2(0, -distance)
		_:
			return Vector2(0, distance)
