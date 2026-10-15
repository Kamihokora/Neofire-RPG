extends "res://combat/battle/pile_view.gd"
## 复用战斗网格/卡面/放大动画，手机仅增加筛选栏并把检查层放到滚动区外。

const TYPES := [[-1, "全部"], [CardData.Type.ATTACK, "攻击"], [CardData.Type.SKILL, "技能"], [CardData.Type.POWER, "能力"], [CardData.Type.TALK, "交涉"]]
const PINK := Color("ff4263")
var _all_ids: Array[String] = []
var _type_filter := -1
var _rarity_filter := -1
var _sort_order := 0
var _bar: HBoxContainer
var _type_buttons: Array[Button] = []
var _rarity: OptionButton
var _sort: OptionButton
var _count: Label
var _floating_inspector: Control


func _ready() -> void:
	super._ready()
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = Vector2(1260, 595)
	size = custom_minimum_size
	get_child(0).hide() # 不叠加战斗查看器的第二层黑幕。
	_panel.position = Vector2.ZERO
	_panel.size = size
	_panel.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	_title.hide()
	_close.hide()
	_bar = HBoxContainer.new()
	_bar.name = "DeckFilters"
	_bar.position = Vector2(0, 4)
	_bar.add_theme_constant_override(&"separation", 12)
	add_child(_bar)
	for entry: Array in TYPES:
		var button := Button.new()
		button.text = str(entry[1])
		button.name = "Type%d" % int(entry[0])
		button.custom_minimum_size = Vector2(104, 56)
		button.pressed.connect(func() -> void:
			_type_filter = int(entry[0])
			_refresh())
		_bar.add_child(button)
		_type_buttons.append(button)
	_rarity = OptionButton.new()
	_rarity.name = "RarityFilter"
	for text: String in ["全部稀有度", "基础", "普通", "罕见", "稀有"]:
		_rarity.add_item(text)
	_rarity.custom_minimum_size = Vector2(200, 56)
	_bar.add_child(_rarity)
	_rarity.item_selected.connect(func(index: int) -> void:
		_rarity_filter = index - 1
		_refresh())
	_sort = OptionButton.new()
	_sort.name = "DeckSort"
	for text: String in ["获得顺序", "按类型", "按费用", "按名称", "按稀有度"]:
		_sort.add_item(text)
	_sort.custom_minimum_size = Vector2(200, 56)
	_bar.add_child(_sort)
	_sort.item_selected.connect(func(index: int) -> void:
		_sort_order = index
		_refresh())
	_count = Label.new()
	_count.position = Vector2(0, 67)
	_count.add_theme_font_size_override(&"font_size", 22)
	_panel.add_child(_count)
	_rows.columns = 4
	set_process_unhandled_key_input(false) # Esc优先由手机转交，防止同时收起详情。


func configure(inspector_host: Control, ids: Array[String]) -> void:
	_all_ids.assign(ids)
	_inspect_layer.reparent(inspector_host, false)
	_inspect_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inspect_layer.z_index = 70
	_floating_inspector = _inspect_layer
	var inspect_buttons: Array[Button] = [_inspect_previous, _inspect_next, _inspect_layer.get_node("Close")]
	for index in inspect_buttons.size():
		var button := inspect_buttons[index]
		button.focus_mode = Control.FOCUS_ALL
		button.focus_neighbor_left = inspect_buttons[posmod(index - 1, 3)].get_path()
		button.focus_neighbor_right = inspect_buttons[(index + 1) % 3].get_path()
		button.focus_neighbor_top = button.get_path()
		button.focus_neighbor_bottom = button.get_path()
		button.focus_previous = button.focus_neighbor_left
		button.focus_next = button.focus_neighbor_right
	_refresh()


func _refresh() -> void:
	var filtered: Array[String] = []
	for id: String in _all_ids:
		var card: CardData = CardDB.get_card(id)
		if card != null and (_type_filter == -1 or card.type == _type_filter) and (_rarity_filter == -1 or card.rarity == _rarity_filter):
			filtered.append(id)
	if _sort_order != 0:
		filtered.sort_custom(_comes_before)
	open_view("卡组", filtered, true)
	_scroll.position = Vector2(0, 100)
	_scroll.size = Vector2(1260, 495)
	_count.text = "显示 %d / %d 张  ·  悬停查看，点击放大" % [filtered.size(), _all_ids.size()]
	for index in _type_buttons.size():
		var style := StyleBoxFlat.new()
		style.bg_color = PINK if int(TYPES[index][0]) == _type_filter else Color("17171c")
		style.border_color = Color.WHITE
		style.set_border_width_all(2)
		_type_buttons[index].add_theme_stylebox_override(&"normal", style)


func _comes_before(a: String, b: String) -> bool:
	var ca: CardData = CardDB.get_card(a)
	var cb: CardData = CardDB.get_card(b)
	match _sort_order:
		1:
			if ca.type != cb.type: return ca.type < cb.type
		2:
			if ca.cost != cb.cost: return ca.cost < cb.cost
		3:
			if ca.name != cb.name: return ca.name.naturalnocasecmp_to(cb.name) < 0
		4:
			if ca.rarity != cb.rarity: return ca.rarity > cb.rarity
	return a < b


func _add_card(card_id: String, index: int) -> void:
	super._add_card(card_id, index)
	var cell := _rows.get_child(index) as Control
	cell.custom_minimum_size.x = 286
	var card := cell.get_child(0) as BattleCardView
	card.position.x = (286 - BattleCardView.CARD_SIZE.x) * 0.5
	(cell.get_node("Selection") as Control).position = card.position


func _inspection_area_size() -> Vector2:
	return Vector2(1920, 1080)


func _open_inspection(index: int, source: BattleCardView = null) -> void:
	super._open_inspection(index, source)
	if _inspect_layer.visible:
		for control: Control in _bar.get_children():
			control.focus_mode = Control.FOCUS_NONE
		(_inspect_layer.get_node("Close") as Button).grab_focus()


func _reset_inspector() -> void:
	var was_open := _inspect_layer != null and _inspect_layer.visible
	super._reset_inspector()
	if _bar != null:
		for control: Control in _bar.get_children():
			control.focus_mode = Control.FOCUS_ALL
		if was_open and is_visible_in_tree():
			_type_buttons[0].grab_focus()


func handle_inspector_input(event: InputEvent) -> bool:
	if not _inspect_layer.visible:
		return false
	if event.is_action_pressed(&"ui_cancel"):
		_close_inspection()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_LEFT, KEY_RIGHT]:
		_change_inspection(-1 if event.keycode == KEY_LEFT else 1)
	else:
		return false
	return true


func _exit_tree() -> void:
	# 检查层属于舞台，而非详情滚动区；离开应用时显式清理。
	_kill_inspect_tween()
	if is_instance_valid(_floating_inspector):
		_floating_inspector.queue_free()
