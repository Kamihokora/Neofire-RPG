class_name TaScoreboard
extends PanelContainer

# AGENT: Name / score rows. Display only.
# INVARIANT: set_rows replaces. Not a netcode board.
# DO NOT: Persist. Do not autoload.

## Simple scoreboard. PackedStringArray of "Name\t12" or two columns.

var _col: VBoxContainer
var _title: Label
var _list: VBoxContainer


func _init() -> void:
	theme_type_variation = "TaScoreboard"
	_col = VBoxContainer.new()
	add_child(_col)
	_title = Label.new()
	_title.text = "Score"
	_title.theme_type_variation = "TaTitle"
	_col.add_child(_title)
	_list = VBoxContainer.new()
	_col.add_child(_list)


func set_title(text: String) -> void:
	_title.text = text


func set_rows(names: PackedStringArray, scores: PackedStringArray) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.free()
	var n := mini(names.size(), scores.size())
	for i in n:
		var row := HBoxContainer.new()
		var left := Label.new()
		left.text = names[i]
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(left)
		var right := Label.new()
		right.text = scores[i]
		row.add_child(right)
		_list.add_child(row)


func get_row_count() -> int:
	return _list.get_child_count()
