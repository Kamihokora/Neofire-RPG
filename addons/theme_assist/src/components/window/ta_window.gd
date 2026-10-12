class_name TaWindow
extends PanelContainer

# AGENT: Floating chrome + content slot. Not docking. Component layer.
# INVARIANT: Drag is title-bar only. Close hides. Clamped to the viewport.
# DO NOT: Dock, snap to IDE edges, or wrap an inner Window node.

## Movable panel with a title bar. get_content() is the user slot.

var _column: VBoxContainer
var _title_bar: PanelContainer
var _mark: TextureRect
var _title: Label
var _close: Button
var _content: VBoxContainer
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

@export var title: String = "":
	set(value):
		title = value
		_apply_title()

@export var closable: bool = true:
	set(value):
		closable = value
		_apply_close()


func _init() -> void:
	theme_type_variation = "TaWindow"
	var title_h := _title_height()
	_column = VBoxContainer.new()
	add_child(_column)
	_title_bar = PanelContainer.new()
	_title_bar.theme_type_variation = "TaWindowTitleBar"
	_title_bar.custom_minimum_size.y = title_h
	_title_bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_title_bar.gui_input.connect(_on_title_gui_input)
	_column.add_child(_title_bar)
	var bar_row := HBoxContainer.new()
	_title_bar.add_child(bar_row)
	_mark = TextureRect.new()
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_mark.visible = false
	bar_row.add_child(_mark)
	_title_bar.theme_changed.connect(_sync_mark)
	_title = Label.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar_row.add_child(_title)
	_close = TaButton.new()
	_close.text = TaDefaults.MODAL_CLOSE
	_close.custom_minimum_size = Vector2(title_h, title_h)
	_close.pressed.connect(_on_close_pressed)
	bar_row.add_child(_close)
	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(_content)
	_apply_title()
	_apply_close()
	refresh_metrics()


func _ready() -> void:
	TaJuice.bind_hover(_close)
	if visible:
		TaJuice.open_control(self)


func refresh_metrics() -> void:
	var min_w := TaLook.metric(TaDefaults.WINDOW_MIN_WIDTH, TaDefaults.PIXEL_WINDOW_MIN_WIDTH)
	var min_h := TaLook.metric(TaDefaults.WINDOW_MIN_HEIGHT, TaDefaults.PIXEL_WINDOW_MIN_HEIGHT)
	custom_minimum_size = Vector2(min_w, min_h)
	var title_h := _title_height()
	if is_instance_valid(_title_bar):
		_title_bar.custom_minimum_size.y = title_h
	if is_instance_valid(_close):
		_close.custom_minimum_size = Vector2(title_h, title_h)


## The look's title mark (a theme icon on the title bar, Framed's framed gem) before the
## title; hidden when the look has none.
func _sync_mark() -> void:
	if not is_instance_valid(_mark) or not is_instance_valid(_title_bar):
		return
	var has := _title_bar.has_theme_icon("mark")
	_mark.texture = _title_bar.get_theme_icon("mark") if has else null
	_mark.visible = has


func _title_height() -> int:
	return TaLook.metric(TaDefaults.WINDOW_TITLE_HEIGHT, TaDefaults.PIXEL_WINDOW_TITLE_HEIGHT)


## Inner slot. Add your body controls as children of this node.
func get_content() -> Control:
	return _content


func _apply_title() -> void:
	if is_instance_valid(_title):
		_title.text = title


func _apply_close() -> void:
	if is_instance_valid(_close):
		_close.visible = closable


func _on_close_pressed() -> void:
	var tween := TaJuice.close_control(self)
	if tween:
		await tween.finished
	if not is_instance_valid(self):
		return
	hide()
	modulate.a = 1.0
	scale = Vector2.ONE


func _on_title_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_dragging = true
			_drag_offset = get_global_mouse_position() - global_position
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() - _drag_offset
		_clamp_to_viewport()


func _clamp_to_viewport() -> void:
	if not is_inside_tree():
		return
	var rect := get_viewport().get_visible_rect()
	var pos := global_position
	var max_x := rect.position.x + maxf(rect.size.x - size.x, 0.0)
	var max_y := rect.position.y + maxf(rect.size.y - size.y, 0.0)
	pos.x = clampf(pos.x, rect.position.x, max_x)
	pos.y = clampf(pos.y, rect.position.y, max_y)
	if pos != global_position:
		global_position = pos
