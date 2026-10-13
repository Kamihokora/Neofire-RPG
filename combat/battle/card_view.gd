class_name BattleCardView
extends Button
## 一张手牌的显示件。全部用代码搭，省得为每张卡建场景。
## 手绘卡面接口：CardData.art 有图就用图，没有就用按类型上色的纯色卡面。

const CARD_SIZE := Vector2(152.0, 208.0)

const TYPE_COLORS := {
	CardData.Type.ATTACK: Color("#8a2f2f"),
	CardData.Type.SKILL: Color("#2f5a8a"),
	CardData.Type.POWER: Color("#6a4b8a"),
	CardData.Type.TALK: Color("#2f7a5a"),
}

var card: CardData = null

var _art: TextureRect
var _tint: ColorRect
var _cost: Label
var _title: Label
var _desc: Label
var _type: Label


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	focus_mode = Control.FOCUS_NONE
	clip_contents = true

	_tint = ColorRect.new()
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)

	_art = TextureRect.new()
	_art.position = Vector2(6.0, 6.0)
	_art.size = Vector2(CARD_SIZE.x - 12.0, 96.0)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)

	_cost = _make_label(Vector2(6.0, 2.0), Vector2(40.0, 40.0), 30)
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title = _make_label(Vector2(6.0, 104.0), Vector2(CARD_SIZE.x - 12.0, 26.0), 19)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type = _make_label(Vector2(6.0, 130.0), Vector2(CARD_SIZE.x - 12.0, 20.0), 15)
	_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc = _make_label(Vector2(8.0, 152.0), Vector2(CARD_SIZE.x - 16.0, 50.0), 14)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP


func _make_label(pos: Vector2, box: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = box
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", Color.WHITE)
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override(&"outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


## 必须先 add_child 再调 setup（子节点是 _ready 里建的）
func setup(data: CardData) -> void:
	card = data
	if data == null:
		return
	_cost.text = str(data.cost)
	_title.text = data.name
	_type.text = data.type_name()
	_desc.text = data.description
	_tint.color = TYPE_COLORS.get(data.type, Color("#3a3a4a"))
	if not data.art.is_empty() and ResourceLoader.exists(data.art):
		_art.texture = load(data.art)
		_art.visible = true
	else:
		_art.visible = false


func set_playable(value: bool) -> void:
	disabled = not value
	modulate = Color.WHITE if value else Color(0.55, 0.55, 0.6, 0.85)
