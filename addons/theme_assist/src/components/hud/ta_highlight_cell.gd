class_name TaHighlightCell
extends PanelContainer

# AGENT: Win-highlight / selected reel cell chrome. Not symbol art.
# INVARIANT: set_selected toggles TaHighlightCellOn. Display only.
# DO NOT: Own a slot machine.

## One cell. Put a Label or TextureRect inside get_content().

var _body: VBoxContainer
var _selected: bool = false


func _init() -> void:
	theme_type_variation = "TaHighlightCell"
	_body = VBoxContainer.new()
	add_child(_body)


func get_content() -> VBoxContainer:
	return _body


func set_selected(on: bool) -> void:
	_selected = on
	theme_type_variation = "TaHighlightCellOn" if on else "TaHighlightCell"


func is_selected() -> bool:
	return _selected
