class_name TaHeaderPanel
extends PanelContainer

# AGENT: Panel with a title bar and content slot. Not a window; not docking.
# INVARIANT: get_content() is the user slot. Title is header-only.
# DO NOT: Drag, close, or wrap an inner Window node.

## Panel with a header row. get_content() is the body slot.

@export var title: String = "":
	set(value):
		title = value
		_apply_title()

var _column: VBoxContainer
var _title_bar: PanelContainer
var _title: Label
var _trailing: HBoxContainer
var _mark: TextureRect
var _content: VBoxContainer


func _init() -> void:
	theme_type_variation = "TaHeaderPanel"
	_column = VBoxContainer.new()
	add_child(_column)
	_title_bar = PanelContainer.new()
	_title_bar.theme_type_variation = "TaHeaderBar"
	_column.add_child(_title_bar)
	var bar := HBoxContainer.new()
	_title_bar.add_child(bar)
	_mark = TextureRect.new()
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_mark.visible = false
	bar.add_child(_mark)
	_title_bar.theme_changed.connect(_sync_mark)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.theme_type_variation = "TaTitle"
	bar.add_child(_title)
	_trailing = HBoxContainer.new()
	bar.add_child(_trailing)
	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(_content)
	_apply_title()
	refresh_metrics()


func refresh_metrics() -> void:
	var title_h := TaLook.metric(
			TaDefaults.WINDOW_TITLE_HEIGHT, TaDefaults.PIXEL_WINDOW_TITLE_HEIGHT
	)
	if is_instance_valid(_title_bar):
		_title_bar.custom_minimum_size.y = title_h


## The look's title mark (a theme icon on the title bar, Framed's framed gem) before the
## title; hidden when the look has none.
func _sync_mark() -> void:
	if not is_instance_valid(_mark) or not is_instance_valid(_title_bar):
		return
	var has := _title_bar.has_theme_icon("mark")
	_mark.texture = _title_bar.get_theme_icon("mark") if has else null
	_mark.visible = has


func get_content() -> VBoxContainer:
	return _content


func get_trailing() -> HBoxContainer:
	return _trailing


func add_trailing(control: Control) -> void:
	if is_instance_valid(control) and is_instance_valid(_trailing):
		_trailing.add_child(control)


func _apply_title() -> void:
	if is_instance_valid(_title):
		_title.text = title
