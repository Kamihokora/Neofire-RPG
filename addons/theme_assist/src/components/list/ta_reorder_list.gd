class_name TaReorderList
extends PanelContainer

# AGENT: Vertical list with up/down movers. Display order only.
# INVARIANT: get_items() matches row order. move_item swaps and rebuilds.
# DO NOT: Drag-drop loot. Do not persist.

## Reorderable rows. order_changed after a move.

signal order_changed(items: PackedStringArray)

var _col: VBoxContainer
var _items: PackedStringArray = PackedStringArray()


func _init() -> void:
	theme_type_variation = "TaReorderList"
	_col = VBoxContainer.new()
	add_child(_col)
	refresh_metrics()


func refresh_metrics() -> void:
	var sep := TaLook.metric(TaDefaults.SEPARATION, TaDefaults.PIXEL_SEPARATION)
	if is_instance_valid(_col):
		_col.add_theme_constant_override("separation", sep)
		var look := TaLook.current()
		var h := TaLook.button_height()
		for row in _col.get_children():
			for i in range(1, row.get_child_count()):
				(row.get_child(i) as Control).custom_minimum_size = Vector2(h, h)


func set_items(items: PackedStringArray) -> void:
	_items = items.duplicate()
	_rebuild()


func get_items() -> PackedStringArray:
	return _items.duplicate()


func add_row(text: String) -> void:
	_items.append(text)
	_rebuild()


func move_item(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= _items.size():
		return
	if to_index < 0 or to_index >= _items.size():
		return
	if from_index == to_index:
		return
	var value := _items[from_index]
	_items.remove_at(from_index)
	_items.insert(to_index, value)
	_rebuild()
	order_changed.emit(get_items())


func move_up(index: int) -> void:
	move_item(index, index - 1)


func move_down(index: int) -> void:
	move_item(index, index + 1)


## The pressed arrow is freed by the rebuild, so move after its signal returns,
## then keep keyboard focus on the moved row (same arrow, or the other at an end).
func _on_arrow(index: int, step: int) -> void:
	call_deferred("_move_and_focus", index, step)


func _move_and_focus(index: int, step: int) -> void:
	var target := index + step
	move_item(index, target)
	if target < 0 or target >= _col.get_child_count():
		return
	var row := _col.get_child(target)
	var same := row.get_child(1 if step < 0 else 2) as Button
	var other := row.get_child(2 if step < 0 else 1) as Button
	var pick := same if same != null and not same.disabled else other
	if pick != null and pick.is_inside_tree():
		pick.grab_focus()


func _rebuild() -> void:
	if not is_instance_valid(_col):
		return
	for child in _col.get_children():
		_col.remove_child(child)
		child.free()
	# Square movers one button tall (look.button_min_height: HUD rows are thinner).
	var look := TaLook.current()
	var h := TaLook.button_height()
	for i in _items.size():
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = _items[i]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		var up := TaButton.new()
		up.custom_minimum_size = Vector2(h, h)
		up.disabled = i == 0
		up.pressed.connect(_on_arrow.bind(i, -1))
		row.add_child(up)
		var down := TaButton.new()
		down.custom_minimum_size = Vector2(h, h)
		down.disabled = i == _items.size() - 1
		down.pressed.connect(_on_arrow.bind(i, 1))
		row.add_child(down)
		_col.add_child(row)
		TaJuice.bind_hover(up)
		TaJuice.bind_hover(down)
	_paint_arrows()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_paint_arrows()


## Drawn arrows from the look (TaThemeStock), or the text arrows with no kit Theme.
func _paint_arrows() -> void:
	if not is_instance_valid(_col):
		return
	var drawn := has_theme_icon("move_up", "TaReorderList")
	for row in _col.get_children():
		if row.get_child_count() < 3:
			continue
		_paint_arrow(row.get_child(1) as Button, "move_up", TaDefaults.REORDER_UP, drawn)
		_paint_arrow(row.get_child(2) as Button, "move_down", TaDefaults.REORDER_DOWN, drawn)


func _paint_arrow(button: Button, icon_name: StringName, fallback: String, drawn: bool) -> void:
	if button == null:
		return
	button.icon = get_theme_icon(icon_name, "TaReorderList") if drawn else null
	button.text = "" if drawn else fallback
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
