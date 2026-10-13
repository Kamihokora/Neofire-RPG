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

## 稀有度 → 卡框贴图（dobo UI 卡片框）+ 标题颜色（sts2 那套：金>紫>蓝>灰）
const RARITY_FRAMES := {
	CardData.Rarity.BASIC: "res://assets/ui/cards/card_black.png",
	CardData.Rarity.COMMON: "res://assets/ui/cards/card_blue.png",
	CardData.Rarity.UNCOMMON: "res://assets/ui/cards/card_purple.png",
	CardData.Rarity.RARE: "res://assets/ui/cards/card_yellow.png",
}
const RARITY_COLORS := {
	CardData.Rarity.BASIC: Color(0.92, 0.92, 0.95),
	CardData.Rarity.COMMON: Color(0.55, 0.8, 1.0),
	CardData.Rarity.UNCOMMON: Color(0.75, 0.6, 1.0),
	CardData.Rarity.RARE: Color(1.0, 0.82, 0.35),
}

var card: CardData = null

var _frame: TextureRect
var _art: TextureRect
var _tint: ColorRect
var _cost: Label
var _title: Label
var _desc: Label
var _type: Label
var _hover_tween: Tween = null


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	focus_mode = Control.FOCUS_NONE
	clip_contents = true

	# 卡框（稀有度颜色）+ 类型色块 + 插图 + 文字
	_frame = TextureRect.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

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

	# 悬停抬手 + 变亮（出牌手感）
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


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
	if _cost == null or _title == null or _type == null or _desc == null or _frame == null:
		# 子节点是在 _ready 里建的；没进树就 setup 会往 null 上写 text（踩过）
		push_warning("[BattleCardView] setup() 必须在 add_child 之后再调")
		return
	_cost.text = str(data.cost)
	_title.text = data.name
	_type.text = data.type_name()
	_desc.text = data.description
	# 类型色作为插画下方的色带；稀有度用卡框 + 标题颜色区分
	_tint.color = Color(TYPE_COLORS.get(data.type, Color("#3a3a4a")), 0.55)
	var frame := str(RARITY_FRAMES.get(data.rarity, RARITY_FRAMES[CardData.Rarity.BASIC]))
	if ResourceLoader.exists(frame):
		_frame.texture = load(frame)
		_frame.visible = true
	else:
		_frame.visible = false
	_title.add_theme_color_override(&"font_color", RARITY_COLORS.get(data.rarity, RARITY_COLORS[CardData.Rarity.BASIC]))
	if not data.art.is_empty() and ResourceLoader.exists(data.art):
		_art.texture = load(data.art)
		_art.visible = true
	else:
		_art.visible = false


func set_playable(value: bool) -> void:
	disabled = not value
	modulate = Color.WHITE if value else Color(0.55, 0.55, 0.6, 0.85)


## 悬停抬手 + 提亮（可打的牌才亮）
func _on_hover(on: bool) -> void:
	if disabled:
		return
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, ^"scale", Vector2(1.07, 1.07) if on else Vector2.ONE, 0.08)
	self_modulate = Color(1.15, 1.15, 1.2) if on else Color.WHITE
