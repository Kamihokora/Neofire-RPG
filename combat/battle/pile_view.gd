class_name BattlePileView
extends Control
## 抽牌堆 / 弃牌堆查看器（点牌堆按钮弹出）。
##
## 结构全用代码搭，省得再维护一个场景。点击背景或右上角「关闭」收起。

signal closed

const ROW_HEIGHT := 34.0

var _title: Label
var _rows: VBoxContainer
var _panel: Panel
var _scroll: ScrollContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	_panel = Panel.new()
	_panel.position = Vector2(560.0, 120.0)
	_panel.size = Vector2(800.0, 840.0)
	add_child(_panel)

	_title = Label.new()
	_title.position = Vector2(28.0, 18.0)
	_title.size = Vector2(600.0, 44.0)
	_title.add_theme_font_size_override(&"font_size", 34)
	_title.add_theme_color_override(&"font_color", Color(1, 0.95, 0.85))
	_panel.add_child(_title)

	var close := Button.new()
	close.text = "关闭"
	close.position = Vector2(660.0, 16.0)
	close.size = Vector2(120.0, 48.0)
	close.pressed.connect(func() -> void: close_view())
	_panel.add_child(close)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(24.0, 76.0)
	_scroll.size = Vector2(752.0, 744.0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)

	_rows = VBoxContainer.new()
	_rows.custom_minimum_size = Vector2(720.0, 0.0)
	_rows.add_theme_constant_override(&"separation", 6)
	_scroll.add_child(_rows)


func open_view(title: String, card_ids: Array) -> void:
	_title.text = "%s（%d 张）" % [title, card_ids.size()]
	for child in _rows.get_children():
		child.queue_free()
	if card_ids.is_empty():
		_add_row("—— 空 ——", 0, "")
	else:
		var sorted_ids := card_ids.duplicate()
		sorted_ids.sort()
		for id: Variant in sorted_ids:
			var card: CardData = CardDB.get_card(str(id))
			if card == null:
				_add_row(str(id), 0, "（未知卡）")
			else:
				_add_row(card.name, card.cost, card.description)
	visible = true


func close_view() -> void:
	visible = false
	closed.emit()


func _add_row(card_name: String, cost: int, description: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)

	var cost_label := Label.new()
	cost_label.text = "[%d]" % cost if cost > 0 else "[—]"
	cost_label.custom_minimum_size = Vector2(56.0, 0.0)
	cost_label.add_theme_font_size_override(&"font_size", 22)
	cost_label.add_theme_color_override(&"font_color", Color(1, 0.9, 0.55))
	row.add_child(cost_label)

	var name_label := Label.new()
	name_label.text = card_name
	name_label.custom_minimum_size = Vector2(200.0, 0.0)
	name_label.add_theme_font_size_override(&"font_size", 22)
	name_label.add_theme_color_override(&"font_color", Color.WHITE)
	row.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = description
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.add_theme_font_size_override(&"font_size", 18)
	desc_label.add_theme_color_override(&"font_color", Color(0.82, 0.84, 0.9))
	row.add_child(desc_label)

	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	_rows.add_child(row)


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_view()
