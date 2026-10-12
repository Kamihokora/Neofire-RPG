class_name TaItemTooltip
extends PanelContainer

# AGENT: Hover tooltip that follows the mouse. Component layer.
# INVARIANT: mouse_filter IGNORE so it cannot steal the target hover.
# DO NOT: Nest CK3-style tooltips. Delay comes from TaDefaults.

## Title, body, optional icon. attach() shows on hover after a delay.

@export var title: String = "":
	set(value):
		title = value
		_apply_copy()

@export var body: String = "":
	set(value):
		body = value
		_apply_copy()

@export var icon: Texture2D:
	set(value):
		icon = value
		_apply_icon()

var _target: Control
var _timer: Timer
var _row: HBoxContainer
var _icon_rect: TextureRect
var _title: Label
var _body: Label


func _init() -> void:
	theme_type_variation = "TaItemTooltip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	top_level = true
	z_index = TaDefaults.TOOLTIP_Z_INDEX
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_icon_rect = TextureRect.new()
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cell := TaLook.metric(TaDefaults.SLOT_SIZE, TaDefaults.PIXEL_SLOT_SIZE)
	_icon_rect.custom_minimum_size = Vector2(cell, cell)
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.visible = false
	_row.add_child(_icon_rect)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(column)
	_title = Label.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_title)
	_body = Label.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_body_color()
	column.add_child(_body)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_delay_elapsed)
	add_child(_timer)
	_apply_copy()
	_apply_icon()
	set_process(false)


## Hover-show / mouse-exit-hide on target. Replaces a previous attach.
func attach(target: Control) -> void:
	if is_instance_valid(_target):
		_disconnect_target(_target)
	_target = target
	if not is_instance_valid(target):
		return
	target.mouse_entered.connect(_on_target_entered)
	target.mouse_exited.connect(_on_target_exited)
	if get_parent() == null:
		if target.is_inside_tree():
			target.add_child(self)
		elif not target.tree_entered.is_connected(_on_target_tree_entered):
			target.tree_entered.connect(_on_target_tree_entered, CONNECT_ONE_SHOT)


func _on_target_tree_entered() -> void:
	if get_parent() == null and is_instance_valid(_target) and _target.is_inside_tree():
		_target.add_child(self)


func refresh_metrics() -> void:
	var cell := TaLook.metric(TaDefaults.SLOT_SIZE, TaDefaults.PIXEL_SLOT_SIZE)
	if is_instance_valid(_icon_rect):
		_icon_rect.custom_minimum_size = Vector2(cell, cell)
	_fit_body()


func _process(_delta: float) -> void:
	if visible:
		_follow_mouse()


func _disconnect_target(target: Control) -> void:
	if target.mouse_entered.is_connected(_on_target_entered):
		target.mouse_entered.disconnect(_on_target_entered)
	if target.mouse_exited.is_connected(_on_target_exited):
		target.mouse_exited.disconnect(_on_target_exited)


func _on_target_entered() -> void:
	_timer.start(TaDefaults.TOOLTIP_DELAY_SECONDS)


func _on_target_exited() -> void:
	_timer.stop()
	visible = false
	set_process(false)


func _on_delay_elapsed() -> void:
	visible = true
	set_process(true)
	_follow_mouse()


func _follow_mouse() -> void:
	var vp := get_viewport().get_visible_rect()
	var mouse := get_viewport().get_mouse_position()
	var offset := Vector2(TaDefaults.TOOLTIP_OFFSET, TaDefaults.TOOLTIP_OFFSET)
	var pos := mouse + offset
	if pos.x + size.x > vp.size.x:
		pos.x = mouse.x - size.x - offset.x
	if pos.y + size.y > vp.size.y:
		pos.y = mouse.y - size.y - offset.y
	pos.x = maxf(pos.x, vp.position.x)
	pos.y = maxf(pos.y, vp.position.y)
	global_position = pos


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_apply_body_color()
		# The body takes its font after this node hears the change: measure afterwards.
		call_deferred("_fit_body")


func get_body_label() -> Label:
	return _body


func _apply_copy() -> void:
	if is_instance_valid(_title):
		_title.text = title
		_title.visible = not title.is_empty()
	if is_instance_valid(_body):
		_body.text = body
		_body.visible = not body.is_empty()
		_apply_body_color()
		_fit_body()


## Wrap at the max width, but hug a short body ("Heals 5" was a 280 px box).
func _fit_body() -> void:
	if is_instance_valid(_body):
		_body.custom_minimum_size.x = fit_width(_body, _body_width())


## Width for an autowrap Label: its text on one line, capped at max_width. The cap
## is where it wraps; below it the label is as wide as its words.
static func fit_width(label: Label, max_width: float) -> float:
	var font := label.get_theme_font("font")
	if font == null:
		return max_width
	var size := label.get_theme_font_size("font_size")
	var natural := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return minf(max_width, ceilf(natural) + 1.0)


func _body_width() -> float:
	return float(TaLook.metric(TaDefaults.TOOLTIP_MAX_WIDTH, TaDefaults.PIXEL_TOOLTIP_MAX_WIDTH))


func _apply_body_color() -> void:
	if not is_instance_valid(_body):
		return
	var look := TaLook.current()
	_body.add_theme_color_override("font_color", look.color_muted)


func _apply_icon() -> void:
	if not is_instance_valid(_icon_rect):
		return
	_icon_rect.texture = icon
	_icon_rect.visible = icon != null
