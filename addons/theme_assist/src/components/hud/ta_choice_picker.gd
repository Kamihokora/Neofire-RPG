class_name TaChoicePicker
extends PanelContainer

# AGENT: Offer row for level-up / roguelike / 3-choice picks. Display only.
# INVARIANT: choice_count defaults to 3. choice_picked(index) on click.
# DO NOT: Own XP or run a run. Do not persist.

## Heading plus N offer cards. Same job as a Button: pick one.

signal choice_picked(index: int)

const _Card := preload("res://addons/theme_assist/src/components/hud/ta_shop_card.gd")

var _col: VBoxContainer
var _heading: Label
var _row: HBoxContainer
var _count: int = TaDefaults.CHOICE_COUNT


func _init() -> void:
	theme_type_variation = "TaChoicePicker"
	_col = VBoxContainer.new()
	add_child(_col)
	_heading = Label.new()
	_heading.text = "Level up"
	_heading.theme_type_variation = "TaTitle"
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(_heading)
	_row = HBoxContainer.new()
	_col.add_child(_row)
	_rebuild()


func set_heading(text: String) -> void:
	_heading.text = text


func set_choice_count(count: int) -> void:
	_count = clampi(count, TaDefaults.CHOICE_MIN, TaDefaults.CHOICE_MAX)
	_rebuild()


func get_choice_count() -> int:
	return _count


func set_choice(index: int, title: String, body: String) -> void:
	var card: Node = get_choice(index)
	if card == null:
		return
	if card.has_method("set_title"):
		card.set_title(title)
	if card.has_method("set_price"):
		card.set_price(body)


func pick(index: int) -> void:
	_on_pick(index)


func get_choice(index: int) -> Node:
	if index < 0 or index >= _row.get_child_count():
		return null
	return _row.get_child(index)


func _rebuild() -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.free()
	for i in _count:
		var card = _Card.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.set_lock_visible(false)
		card.set_title("Choice %d" % (i + 1))
		card.set_price("")
		var idx := i
		card.pressed.connect(func() -> void: _on_pick(idx))
		_row.add_child(card)


func _on_pick(index: int) -> void:
	for i in _row.get_child_count():
		var card = _row.get_child(i)
		if card.has_method("set_selected"):
			card.set_selected(i == index)
	choice_picked.emit(index)
