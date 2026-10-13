@tool
class_name NeofireStoryDialogue
extends DialogicLayoutBase
## A 系统（方案A）：全屏剧情对话 —— 背景 + 立绘上舞台 + 底部对话框。
##
## 布局数值沿用你原来 test_story_dialogue.tscn 里手工调好的那套（底板 9-slice / 名字牌位 /
## 正文字号 44 / 继续箭头翻转），只是把数据层换成 Dialogic。
## 立绘由 Dialogic 的 Character 事件驱动：剧本里写 `join 敌人 (default) center` 就会出现。
##
## 跟"气泡跟头顶"那套（neofire_box）是两套样式；DialoguePlayer 的 style 字段决定用哪套。

@export_group("背景")
## 是否铺全屏背景图。默认关：直接在游戏图版（地图）上对话，
## 只有需要像 VN 那样切到专用背景的场合才打开。
@export var show_background: bool = false
## 背景图（show_background 打开时用）
@export_file("*.png", "*.jpg", "*.webp") var background_image: String = "res://assets/backgrounds/bg_school.png"

@export_group("选项（Dialogic 分支）")
## 容器必须一直 visible：Dialogic 会先 hide_all_choices() 再找按钮，且要求按钮 is_visible_in_tree()
@export var choice_count: int = 5
@export var choice_font_size: int = 34
@export var choice_width: float = 720.0
@export var choice_height: float = 64.0

@export_group("配色取舍")
## 是否用角色自己的 name_color 上色（默认关 = 白字，跟你原来调好的一致）
@export var use_character_name_color: bool = false

@export_group("开合动画")
@export var open_duration: float = 0.14
@export var close_duration: float = 0.18
@export var open_from_scale: float = 0.94

const NARRATOR_COLOR := Color(0.8, 0.8, 0.8)
const NAME_COLOR := Color.WHITE

@onready var _box: Panel = $DialogueBox
@onready var _name_label: Label = $DialogueBox/NamePlate/NameLabel
@onready var _text_label: RichTextLabel = $DialogueBox/TextLabel
@onready var _continue_hint: TextureRect = $DialogueBox/ContinueHint
@onready var _choices: VBoxContainer = $Choices

var _box_tween: Tween = null
var _open_seq := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_box.visible = false
	# 同上：空名字时隐藏整个名字牌
	_name_label.set(&"hide_when_empty", true)
	_name_label.set(&"name_label_root", $DialogueBox/NamePlate)
	_apply_background()
	Dialogic.timeline_started.connect(_on_timeline_started)
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	Dialogic.Text.about_to_show_text.connect(_on_about_to_show_text)
	_build_choice_buttons()
	Dialogic.Choices.question_shown.connect(_on_question_shown)
	Dialogic.Choices.choice_selected.connect(_on_choice_selected)
	_text_label.connect(&"started_revealing_text", func() -> void: _continue_hint.visible = false)
	_text_label.connect(&"finished_revealing_text", func() -> void: _continue_hint.visible = true)


## 背景：默认全部隐藏，让地图自己透出来
func _apply_background() -> void:
	var bg: Node = get_node_or_null(^"Background")
	var img: TextureRect = get_node_or_null(^"BackgroundImage") as TextureRect
	if bg != null:
		(bg as CanvasItem).visible = show_background
	if img != null:
		img.visible = show_background
		if show_background and not background_image.is_empty() and ResourceLoader.exists(background_image):
			img.texture = load(background_image)


#region 文本表现
################################################################################

func _on_about_to_show_text(info: Dictionary) -> void:
	var character: DialogicCharacter = info.get("character", null)
	if character == null:
		# 旁白：整块名字牌收起来（同 neofire_box 的说明）
		(get_node(^"DialogueBox/NamePlate") as CanvasItem).visible = false
		_text_label.add_theme_color_override(&"default_color", NARRATOR_COLOR)
	else:
		_text_label.add_theme_color_override(&"default_color", Color.WHITE)
		_name_label.add_theme_color_override(&"font_color",
			character.color if use_character_name_color else NAME_COLOR)

#endregion


#region 分支选项
################################################################################

func _build_choice_buttons() -> void:
	for child in _choices.get_children():
		child.queue_free()
	for i in choice_count:
		var button := DialogicNode_ChoiceButton.new()
		button.name = "Choice%d" % (i + 1)
		button.custom_minimum_size = Vector2(choice_width, choice_height)
		button.add_theme_font_size_override(&"font_size", choice_font_size)
		button.add_theme_color_override(&"font_color", Color.WHITE)
		button.add_theme_color_override(&"font_hover_color", Color(1, 0.9, 0.7))
		button.add_theme_color_override(&"font_focus_color", Color(1, 0.9, 0.7))
		_choices.add_child(button)
	_choices.visible = true


func _on_question_shown(_info: Dictionary) -> void:
	_choices.visible = true


func _on_choice_selected(_info: Dictionary) -> void:
	_choices.visible = true
#endregion


#region 出现 / 收场
################################################################################

func _on_timeline_started() -> void:
	_open()


func _on_timeline_ended() -> void:
	Dialogic.Choices.hide_all_choices()
	_close()


func _open() -> void:
	_open_seq += 1
	_box.visible = true
	_box.pivot_offset = _box.size * 0.5
	if _box_tween != null and _box_tween.is_valid():
		_box_tween.kill()
	_box_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_box_tween.tween_property(_box, ^"modulate:a", 1.0, open_duration).from(0.0)


func _close() -> void:
	if not _box.visible:
		return
	_open_seq += 1
	var seq := _open_seq
	if _box_tween != null and _box_tween.is_valid():
		_box_tween.kill()
	if close_duration <= 0.0:
		_box.visible = false
		return
	_box_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_box_tween.tween_property(_box, ^"modulate:a", 0.0, close_duration)
	_box_tween.chain().tween_callback(func() -> void:
		if seq == _open_seq:
			_box.visible = false)
#endregion
