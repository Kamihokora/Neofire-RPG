class_name BattlePileView
extends Control
## 抽牌堆 / 弃牌堆查看器（点牌堆按钮弹出）。
##
## 参照 sts2 的 NCardPileScreen：不列文字，而是把**真正的卡面**铺成网格给你看。
## 卡面复用战斗里的 BattleCardView（所以稀有度卡框/标题颜色在这里也一致）。
## 点背景、右上角「关闭」都能收起。

signal closed
signal selection_finished(indices: Array[int])

const CARD_SCALE := 1.35
const COLUMNS := 4
## 四列大卡；给 1.5 倍悬停卡面和费用球留出完整空间。
const CELL_SIZE := Vector2(302, 346)
const INSPECT_SCALE := 2.6
const PANEL_RECT := Rect2(250.0, 110.0, 1420.0, 860.0)

var _title: Label
## 卡片网格（自检 F13 会数它的子节点数）
var _rows: GridContainer
var _panel: Panel
var _scroll: ScrollContainer
var _close: Button
var _card_ids: Array[String] = []
var _inspect_layer: Control
var _inspect_shade: ColorRect
var _inspect_card: BattleCardView
var _inspect_previous: Button
var _inspect_next: Button
var _inspect_count: Label
var _inspect_index := -1
var _inspect_tween: Tween
var _inspect_closing := false
var _choosing := false
var _source_indices: Array[int] = []
var _eligible: Array[bool] = []
var _selected: Array[int] = []
var _selection_count := 1
var _choice_confirm: Button
var _choice_done: Button
var _choice_note: Label
var _allow_cancel := true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.62)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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
	_close.disabled = false
	_allow_cancel = true
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

	var padding := MarginContainer.new()
	padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "top", "right", "bottom"]:
		padding.add_theme_constant_override(StringName("margin_" + side), 24)
	_scroll.add_child(padding)
	_rows = GridContainer.new()
	_rows.columns = COLUMNS
	_rows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_rows.add_theme_constant_override(&"h_separation", 12)
	_rows.add_theme_constant_override(&"v_separation", 12)
	padding.add_child(_rows)
	_build_inspector()
	_choice_done = Button.new()
	_choice_done.name = "ConfirmSelection"
	_choice_done.position = Vector2(920, 778)
	_choice_done.size = Vector2(472, 54)
	_choice_done.add_theme_font_size_override(&"font_size", 23)
	_style_button(_choice_done)
	_panel.add_child(_choice_done)
	_choice_done.pressed.connect(_finish_selection)
	_choice_note = Label.new()
	_choice_note.position = Vector2(32, 788)
	_choice_note.add_theme_font_size_override(&"font_size", 23)
	_panel.add_child(_choice_note)
	_choice_done.hide()
	_choice_note.hide()


func _style_button(button: Button) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var path := "res://assets/ui/buttons/button_black.png"
	if not ResourceLoader.exists(path):
		return
	var style := preload("res://assets/ui/dobo_button_style.gd").create(path)
	button.add_theme_stylebox_override(&"normal", style)
	button.add_theme_stylebox_override(&"hover", style)
	button.add_theme_stylebox_override(&"pressed", style)
	button.add_theme_stylebox_override(&"focus", style)
	button.add_theme_stylebox_override(&"disabled", style)
	button.add_theme_color_override(&"font_color", Color.WHITE)


## 打开查看器：card_ids 里的每一张都渲染成真卡面
func open_view(title: String, card_ids: Array, preserve_order: bool = false) -> void:
	_choosing = false
	_selected.clear()
	_choice_done.hide()
	_choice_note.hide()
	_close.text = "关闭"
	_scroll.size.y = 756
	_reset_inspector()
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_card_ids.assign(card_ids if preserve_order else _sorted_ids(card_ids))
	_title.text = "%s（%d 张）" % [title, card_ids.size()]
	if card_ids.is_empty():
		var empty := Label.new()
		empty.text = "—— 空的 ——"
		empty.custom_minimum_size = Vector2(400.0, 60.0)
		empty.add_theme_font_size_override(&"font_size", 28)
		empty.add_theme_color_override(&"font_color", Color(0.8, 0.8, 0.85))
		_rows.add_child(empty)
	else:
		for index in _card_ids.size():
			_add_card(_card_ids[index], index)
	_scroll.scroll_vertical = 0
	visible = true


## 保留源位置而非卡名，重复牌和排序后也能返回正确实例。
func choose_cards(title: String, card_ids: Array[String], source_indices: Array[int], count: int, eligible: Array[bool] = [], allow_cancel: bool = true) -> Array[int]:
	open_view(title, card_ids, true)
	_choosing = true
	_source_indices.assign(source_indices)
	_eligible.assign(eligible)
	_selection_count = count
	_allow_cancel = allow_cancel
	_close.text = "取消" if allow_cancel else "选择中"
	_close.disabled = not allow_cancel
	_scroll.size.y = 668
	_choice_note.show()
	_choice_done.visible = count > 1
	_update_choice_labels()
	var result: Array[int] = await selection_finished
	return result


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


func _add_card(card_id: String, index: int) -> void:
	var data: CardData = CardDB.get_card(card_id)
	# 单元格：卡面按 CARD_SCALE 缩放后占的尺寸（scale 不影响布局，所以要自己撑格子）
	var cell := Control.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := BattleCardView.new()
	cell.add_child(view)
	# 先入树再 setup：BattleCardView 的子节点是在 _ready 里建的，
	# 没进树就 setup 会往 null 上写 text（实测报 “base object of type 'Nil'”）。
	_rows.add_child(cell)
	view.position = (CELL_SIZE - BattleCardView.CARD_SIZE) * 0.5
	# pivot 放卡片中心：牌堆里的悬停才是“以自己为中心”放大，
	# 否则（pivot 在左上角）一放大就朝右下长，直接捅出格子/面板外面
	view.pivot_offset = BattleCardView.CARD_SIZE * 0.5
	view.begin_free_move()                # 位置由格子/滚动容器管，不参与手牌版式动画
	view.set_visual_scale(CARD_SCALE)
	view.set_hover_style(1.5, 0.0)
	view.setup(data)
	view.set_playable(true)
	view.pressed.connect(_open_inspection.bind(index, view))
	var selection := Panel.new()
	selection.name = "Selection"
	selection.position = view.position
	selection.size = view.size
	selection.pivot_offset = view.pivot_offset
	selection.scale = Vector2.ONE * CARD_SCALE
	selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border := StyleBoxFlat.new()
	border.bg_color = Color(1, 0.72, 0.12, 0.06)
	border.border_color = Color(1, 0.8, 0.24)
	border.set_border_width_all(3)
	border.set_corner_radius_all(10)
	selection.add_theme_stylebox_override(&"panel", border)
	cell.add_child(selection)
	selection.hide()


func close_view() -> void:
	if _choosing and not _allow_cancel:
		return
	var was_choosing := _choosing
	_choosing = false
	_reset_inspector()
	visible = false
	closed.emit()
	if was_choosing:
		var cancelled: Array[int] = []
		selection_finished.emit(cancelled)


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		get_viewport().set_input_as_handled()
		close_view()


## 参考 StS2 NCardsViewScreen → NInspectCardScreen：查看大卡独立于滚动裁切区。
func _build_inspector() -> void:
	_inspect_layer = Control.new()
	_inspect_layer.name = "Inspector"
	_inspect_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_inspect_layer)
	_inspect_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inspect_shade = ColorRect.new()
	_inspect_shade.color = Color(0.015, 0.02, 0.04, 0.86)
	_inspect_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_inspect_layer.add_child(_inspect_shade)
	_inspect_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inspect_shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			get_viewport().set_input_as_handled()
			_close_inspection())
	_inspect_card = BattleCardView.new()
	_inspect_card.name = "Card"
	_inspect_layer.add_child(_inspect_card)
	_inspect_card.begin_free_move()
	_inspect_card.hover_enabled = false
	_inspect_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect_previous = _inspect_button("Previous", "‹", Vector2(632, 494), Vector2(72, 80))
	_inspect_previous.pressed.connect(_change_inspection.bind(-1))
	_inspect_next = _inspect_button("Next", "›", Vector2(1216, 494), Vector2(72, 80))
	_inspect_next.pressed.connect(_change_inspection.bind(1))
	var close := _inspect_button("Close", "关闭", Vector2(1296, 222), Vector2(132, 54))
	close.pressed.connect(_close_inspection)
	_inspect_count = Label.new()
	_inspect_count.position = Vector2(810, 846)
	_inspect_count.size = Vector2(300, 40)
	_inspect_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inspect_count.add_theme_font_size_override(&"font_size", 24)
	_inspect_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect_layer.add_child(_inspect_count)
	_choice_confirm = _inspect_button("ConfirmCard", "确定", Vector2(816, 908), Vector2(288, 56))
	_choice_confirm.pressed.connect(_confirm_inspected_card)
	_choice_confirm.hide()
	_inspect_layer.hide()


func _inspect_button(node_name: String, text: String, pos: Vector2, box: Vector2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.position = pos
	button.size = box
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", 28)
	_style_button(button)
	_inspect_layer.add_child(button)
	return button


func _open_inspection(index: int, source: BattleCardView = null) -> void:
	if _inspect_closing or index < 0 or index >= _card_ids.size():
		return
	_kill_inspect_tween()
	_inspect_index = index
	_inspect_layer.show()
	_inspect_card.setup(CardDB.get_card(_card_ids[index]))
	_inspect_previous.disabled = index == 0
	_inspect_next.disabled = index == _card_ids.size() - 1
	_inspect_count.text = "%d / %d" % [index + 1, _card_ids.size()]
	_choice_confirm.visible = _choosing
	if _choosing:
		var allowed := _eligible.is_empty() or _eligible[index]
		_choice_confirm.disabled = not allowed or (_selection_count > 1 and _selected.size() >= _selection_count and not _selected.has(index))
		_choice_confirm.text = "取消选中" if _selected.has(index) else "确定"
		_inspect_count.text = ("确定是这张吗？" if _selection_count == 1 else "将这张加入选择？") if allowed else "此牌当前不可打出"
	var center := get_viewport_rect().size * 0.5
	var target := center - BattleCardView.CARD_SIZE * 0.5
	if source != null:
		_inspect_card.global_position = source.global_position
		_inspect_card.scale = source.scale
		_inspect_shade.modulate.a = 0
	else:
		_inspect_card.position = target + Vector2(32, 0)
		_inspect_card.scale = Vector2.ONE * (INSPECT_SCALE * 0.94)
	_inspect_card.modulate.a = 1
	_inspect_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_inspect_tween.tween_property(_inspect_card, ^"position", target, 0.24)
	_inspect_tween.tween_property(_inspect_card, ^"scale", Vector2.ONE * INSPECT_SCALE, 0.24)
	_inspect_tween.tween_property(_inspect_shade, ^"modulate:a", 1.0, 0.2)


func _change_inspection(direction: int) -> void:
	_open_inspection(_inspect_index + direction)


func _close_inspection() -> void:
	if not _inspect_layer.visible or _inspect_closing:
		return
	_kill_inspect_tween()
	_inspect_closing = true
	_inspect_tween = create_tween().set_parallel(true)
	_inspect_tween.tween_property(_inspect_card, ^"scale", Vector2.ONE * (INSPECT_SCALE * 0.94), 0.14)
	_inspect_tween.tween_property(_inspect_card, ^"modulate:a", 0.0, 0.14)
	_inspect_tween.tween_property(_inspect_shade, ^"modulate:a", 0.0, 0.14)
	_inspect_tween.chain().tween_callback(_reset_inspector)


func _kill_inspect_tween() -> void:
	if _inspect_tween != null and _inspect_tween.is_valid():
		_inspect_tween.kill()
	_inspect_tween = null


func _reset_inspector() -> void:
	_kill_inspect_tween()
	_inspect_layer.hide()
	_inspect_closing = false
	_inspect_index = -1
	if _choice_confirm != null:
		_choice_confirm.hide()


func _confirm_inspected_card() -> void:
	if not _choosing or _choice_confirm.disabled:
		return
	if _selection_count == 1:
		_selected.assign([_inspect_index])
		_finish_selection()
		return
	if _selected.has(_inspect_index):
		_selected.erase(_inspect_index)
	else:
		_selected.append(_inspect_index)
	_update_choice_labels()
	_close_inspection()


func _update_choice_labels() -> void:
	_choice_note.text = "点击卡牌放大并确认 · 已选 %d / %d" % [_selected.size(), _selection_count]
	_choice_done.text = "确定是这几张吗？（%d/%d）" % [_selected.size(), _selection_count]
	_choice_done.disabled = _selected.size() != _selection_count
	for index in _rows.get_child_count():
		var frame := _rows.get_child(index).get_node_or_null("Selection") as Control
		if frame != null:
			frame.visible = _selected.has(index)


func _finish_selection() -> void:
	if not _choosing or _selected.size() != _selection_count:
		return
	var result: Array[int] = []
	for index in _selected:
		result.append(_source_indices[index])
	_choosing = false
	close_view()
	selection_finished.emit(result)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed:
		return
	if event.keycode == KEY_ESCAPE:
		if _inspect_layer.visible:
			_close_inspection()
		else:
			close_view()
		get_viewport().set_input_as_handled()
	elif _inspect_layer.visible and event.keycode in [KEY_LEFT, KEY_RIGHT]:
		_change_inspection(-1 if event.keycode == KEY_LEFT else 1)
		get_viewport().set_input_as_handled()
