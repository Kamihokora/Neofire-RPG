class_name TaMinimap
extends PanelContainer

# AGENT: Minimap frame. Content slot is yours (SubViewport, TextureRect, …).
# INVARIANT: get_content() is empty chrome. Kit does not draw a map.
# DO NOT: Pathfind. Do not own world cameras.

## Framed MAP panel. Drop a SubViewport into get_content().

var _col: VBoxContainer
var _title: Label
var _content: Control


func _init() -> void:
	theme_type_variation = "TaMinimap"
	_col = VBoxContainer.new()
	add_child(_col)
	_title = Label.new()
	_title.text = "MAP"
	_title.theme_type_variation = "TaCaption"
	_col.add_child(_title)
	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col.add_child(_content)
	refresh_metrics()


func refresh_metrics() -> void:
	var s := TaLook.metric(TaDefaults.MINIMAP_SIZE, TaDefaults.PIXEL_MINIMAP_SIZE)
	if is_instance_valid(_content):
		_content.custom_minimum_size = Vector2(s, s)


func get_content() -> Control:
	return _content
