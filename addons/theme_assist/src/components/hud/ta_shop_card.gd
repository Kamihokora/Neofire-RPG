class_name TaShopCard
extends PanelContainer

# AGENT: Shop / deal card: title, stats, price. Display only.
# INVARIANT: get_stats() is a VBox you fill. selected toggles chrome. Focusable:
# ui_accept emits pressed, and the Button focus ring draws while focused.
# DO NOT: Own gold or inventory.

## Item card for a between-wave shop or casino deal. Also a list row that sizes to
## its content: hide the lock, put a description in get_stats().

signal pressed
signal lock_toggled(locked: bool)

var _col: VBoxContainer
var _title: Label
var _stats: VBoxContainer
var _price: Label
var _lock: CheckBox
var _selected: bool = false
var _painting: bool = false


func _init() -> void:
	theme_type_variation = "TaShopCard"
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_col = VBoxContainer.new()
	add_child(_col)
	_title = Label.new()
	_title.theme_type_variation = "TaTitle"
	_col.add_child(_title)
	_stats = VBoxContainer.new()
	_col.add_child(_stats)
	_price = Label.new()
	_col.add_child(_price)
	_lock = CheckBox.new()
	_lock.text = "Lock"
	_lock.toggled.connect(func(on: bool) -> void: lock_toggled.emit(on))
	_col.add_child(_lock)
	gui_input.connect(_on_gui)


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		# Hover and focus lift and tick like a TaButton; the lock is a real button.
		TaJuice.bind_hover(self)
		TaJuice.bind_hover(_lock)
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_PARENTED:
		_apply_ink()
	elif what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()


func _draw() -> void:
	if has_focus():
		var ring := get_theme_stylebox("focus", "Button")
		if ring != null:
			draw_style_box(ring, Rect2(Vector2.ZERO, size))


func _ready() -> void:
	_apply_ink()


## Empty lines hide, so a card without a price has no blank line at the bottom.
func set_title(text: String) -> void:
	_title.text = text
	_title.visible = not text.is_empty()


func set_price(text: String) -> void:
	_price.text = text
	_price.visible = not text.is_empty()


func get_stats() -> VBoxContainer:
	return _stats


func set_selected(on: bool) -> void:
	_selected = on
	theme_type_variation = "TaShopCardOn" if on else "TaShopCard"
	_apply_ink()


func is_selected() -> bool:
	return _selected


func set_lock_visible(show: bool) -> void:
	if is_instance_valid(_lock):
		_lock.visible = show


func is_lock_visible() -> bool:
	return is_instance_valid(_lock) and _lock.visible


func _apply_ink() -> void:
	if _painting:
		return
	_painting = true
	# The nearest Theme that has the ink (see TaBadge._paint_ink); a nearer game Theme
	# without TaShopCardOn gave black ink on the accent.
	# Off, the card's own ink (TaCardText: dark on Framed's cream); on, the accent's.
	var item := "TaShopCardOn" if theme_type_variation == "TaShopCardOn" else "TaCardText"
	var source := TaThemeBuilder.theme_with_color(self, "font_color", item)
	var labels: Array[Node] = []
	if is_instance_valid(_title):
		labels.append(_title)
	if is_instance_valid(_price):
		labels.append(_price)
	if is_instance_valid(_stats):
		labels.append_array(_stats.find_children("*", "Label", true, false))
	for label: Label in labels:
		if source != null:
			label.add_theme_color_override("font_color", source.get_color("font_color", item))
		else:
			label.remove_theme_color_override("font_color")
	_painting = false


func set_locked(on: bool) -> void:
	_lock.set_pressed_no_signal(on)


func is_locked() -> bool:
	return _lock.button_pressed


func _on_gui(event: InputEvent) -> void:
	var clicked: bool = (
			event is InputEventMouseButton
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
			and event.pressed
	)
	if clicked or event.is_action_pressed("ui_accept"):
		TaJuice.tap(self)
		pressed.emit()
		accept_event()
