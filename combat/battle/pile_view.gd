class_name BattlePileView
extends Control
## 抽牌堆 / 弃牌堆查看器（点牌堆按钮弹出）。
##
## 参照 sts2 的 NCardPileScreen：不列文字，而是把**真正的卡面**铺成网格给你看。
## 卡面复用战斗里的 BattleCardView（所以稀有度卡框/标题颜色在这里也一致）。
## 点背景、右上角「关闭」都能收起。

signal closed

const CARD_SCALE := 0.85
const COLUMNS := 8
const PANEL_RECT := Rect2(250.0, 110.0, 1420.0, 860.0)

var _title: Label
## 卡片网格（自检 F13 会数它的子节点数）
var _rows: GridContainer
var _panel: Panel
var _scroll: ScrollContainer
var _close: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.62)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	_panel = Panel.new()
	_panel.position = PANEL_RECT.position
	_panel.size = PANEL_RECT.size
	var style := StyleBoxTexture.new()
	if ResourceLoader.exists("res://assets/ui/panels/panel_black.png"):
		style.texture = load("res://assets/ui/panels/panel_black.png")
	style.texture_margin_left = 40.0
	style.texture_margin_top = 40.0
	style.texture_margin_right = 40.0
	style.texture_margin_bottom = 40.0
	style.content_margin_left = 28.0
	style.content_margin_top = 20.0
	style.content_margin_right = 28.0
	style.content_margin_bottom = 20.0
	_panel.add_theme_stylebox_override(&"panel", style)
	add_child(_panel)

	_title = Label.new()
	_title.position = Vector2(28.0, 18.0)
	_title.size = Vector2(900.0, 46.0)
	_title.add_theme_font_size_override(&"font_size", 34)
	_title.add_theme_color_override(&"font_color", Color(1, 0.95, 0.85))
	_title.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	_title.add_theme_constant_override(&"outline_size", 6)
	_panel.add_child(_title)

	_close = Button.new()
	_close.text = "关闭"
	_close.position = Vector2(1250.0, 16.0)
	_close.size = Vector2(140.0, 52.0)
	_close.add_theme_font_size_override(&"font_size", 22)
	_style_button(_close)
	_close.pressed.connect(func() -> void: close_view())
	_panel.add_child(_close)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(24.0, 80.0)
	_scroll.size = Vector2(1372.0, 756.0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)

	_rows = GridContainer.new()
	_rows.columns = COLUMNS
	_rows.add_theme_constant_override(&"h_separation", 10)
	_rows.add_theme_constant_override(&"v_separation", 10)
	_scroll.add_child(_rows)


func _style_button(button: Button) -> void:
	var path := "res://assets/ui/buttons/button_black.png"
	if not ResourceLoader.exists(path):
		return
	var style := StyleBoxTexture.new()
	style.texture = load(path)
	style.texture_margin_left = 24.0
	style.texture_margin_top = 24.0
	style.texture_margin_right = 24.0
	style.texture_margin_bottom = 24.0
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	button.add_theme_stylebox_override(&"normal", style)
	button.add_theme_stylebox_override(&"hover", style)
	button.add_theme_stylebox_override(&"pressed", style)
	button.add_theme_stylebox_override(&"focus", style)
	button.add_theme_color_override(&"font_color", Color.WHITE)


## 打开查看器：card_ids 里的每一张都渲染成真卡面
func open_view(title: String, card_ids: Array) -> void:
	for child in _rows.get_children():
		child.queue_free()
	_title.text = "%s（%d 张）" % [title, card_ids.size()]
	if card_ids.is_empty():
		var empty := Label.new()
		empty.text = "—— 空的 ——"
		empty.custom_minimum_size = Vector2(400.0, 60.0)
		empty.add_theme_font_size_override(&"font_size", 28)
		empty.add_theme_color_override(&"font_color", Color(0.8, 0.8, 0.85))
		_rows.add_child(empty)
	else:
		for id: Variant in _sorted_ids(card_ids):
			_add_card(str(id))
	_scroll.scroll_vertical = 0
	visible = true


## 稀有度高的排前面（金 > 紫 > 蓝 > 灰），同稀有度按费用、再按名字
func _sorted_ids(card_ids: Array) -> Array:
	var ids := card_ids.duplicate()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ca: CardData = CardDB.get_card(str(a))
		var cb: CardData = CardDB.get_card(str(b))
		var ra := ca.rarity if ca != null else CardData.Rarity.BASIC
		var rb := cb.rarity if cb != null else CardData.Rarity.BASIC
		if ra != rb:
			return ra > rb
		var costa := ca.cost if ca != null else 0
		var costb := cb.cost if cb != null else 0
		if costa != costb:
			return costa < costb
		return str(a) < str(b))
	return ids


func _add_card(card_id: String) -> void:
	var data: CardData = CardDB.get_card(card_id)
	# 单元格：卡面按 CARD_SCALE 缩放后占的尺寸（scale 不影响布局，所以要自己撑格子）
	var cell := Control.new()
	cell.custom_minimum_size = BattleCardView.CARD_SIZE * CARD_SCALE
	var view := BattleCardView.new()
	cell.add_child(view)
	# 先入树再 setup：BattleCardView 的子节点是在 _ready 里建的，
	# 没进树就 setup 会往 null 上写 text（实测报 “base object of type 'Nil'”）。
	_rows.add_child(cell)
	view.scale = Vector2(CARD_SCALE, CARD_SCALE)
	view.pivot_offset = Vector2.ZERO
	view.setup(data)
	view.set_playable(true)


func close_view() -> void:
	visible = false
	closed.emit()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close_view()
