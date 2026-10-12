class_name TaButtonRow
extends HBoxContainer

# AGENT: Horizontal button strip. Presentation only.
# INVARIANT: add_button appends a juiced Button. Index is resolved at press.
# DO NOT: Own dialogs or a page stack.

## Row of buttons. button_pressed(index) when one is clicked.

signal button_pressed(index: int)

var _press_depth: int = 0


func _init() -> void:
	theme_type_variation = "TaButtonRow"


func refresh_metrics() -> void:
	var sep := TaLook.metric(TaDefaults.SEPARATION, TaDefaults.PIXEL_SEPARATION)
	add_theme_constant_override("separation", sep)
	var h := TaLook.button_height()
	for child in get_children():
		if child is Button:
			(child as Button).custom_minimum_size.y = h


func add_button(caption: String, on_press: Callable = Callable()) -> Button:
	var button := TaButton.new()
	button.text = caption
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		_press_depth += 1
		_on_pressed(button)
		if on_press.is_valid():
			on_press.call()
		_press_depth -= 1
	)
	add_child(button)
	refresh_metrics()
	# Menu feel for keys and gamepads: the ends wrap; focus can still leave the row.
	TaFocus.wrap(get_buttons(), TaFocus.Axis.HORIZONTAL)
	return button


## Replace every caption. If a button is mid-press, the rebuild waits until the
## signal returns so the clicked button is not freed underneath itself.
func set_captions(captions: PackedStringArray) -> void:
	var next := captions.duplicate()
	if _press_depth > 0:
		call_deferred("_rebuild_captions", next)
		return
	_rebuild_captions(next)


func set_button_text(index: int, caption: String) -> void:
	var buttons := get_buttons()
	if index < 0 or index >= buttons.size():
		return
	buttons[index].text = caption


func set_button_disabled(index: int, disabled: bool) -> void:
	var buttons := get_buttons()
	if index < 0 or index >= buttons.size():
		return
	buttons[index].disabled = disabled


func _rebuild_captions(captions: PackedStringArray) -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	for caption in captions:
		add_button(caption)


func get_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for child in get_children():
		if child is Button:
			out.append(child as Button)
	return out


func _on_pressed(button: Button) -> void:
	button_pressed.emit(get_buttons().find(button))
