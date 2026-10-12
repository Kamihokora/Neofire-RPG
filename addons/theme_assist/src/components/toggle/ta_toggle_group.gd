class_name TaToggleGroup
extends HBoxContainer

# AGENT: Toggle strip. Exclusive uses ButtonGroup; multi allows many on.
# INVARIANT: get_selected() is pressed indexes. Not an InputMap.
# DO NOT: Persist. Do not own settings.

## Row of toggle buttons. Exclusive (radio) or multi.

signal option_toggled(index: int, on: bool)

enum Mode {
	EXCLUSIVE,
	MULTI,
}

@export var mode: Mode = Mode.EXCLUSIVE:
	set(value):
		mode = value
		_apply_mode()

var _group: ButtonGroup


func _init() -> void:
	theme_type_variation = "TaToggleGroup"
	_group = ButtonGroup.new()
	_apply_mode()


func refresh_metrics() -> void:
	var sep := TaLook.metric(TaDefaults.SEPARATION, TaDefaults.PIXEL_SEPARATION)
	add_theme_constant_override("separation", sep)
	var h := TaLook.button_height()
	for child in get_children():
		if child is Button:
			(child as Button).custom_minimum_size.y = h


func add_option(caption: String) -> Button:
	var button := TaButton.new()
	button.text = caption
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var index := get_child_count()
	button.toggled.connect(_on_toggled.bind(index))
	add_child(button)
	_apply_mode()
	refresh_metrics()
	TaFocus.wrap(get_children(), TaFocus.Axis.HORIZONTAL)
	if mode == Mode.EXCLUSIVE and index == 0:
		button.set_pressed_no_signal(true)
	return button


func get_selected() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in get_child_count():
		var button := get_child(i) as Button
		if button != null and button.button_pressed:
			out.append(i)
	return out


func set_selected(indices: PackedInt32Array) -> void:
	var want := {}
	for i in indices:
		want[int(i)] = true
	for i in get_child_count():
		var button := get_child(i) as Button
		if button != null:
			button.set_pressed_no_signal(want.has(i))


func _apply_mode() -> void:
	var exclusive := mode == Mode.EXCLUSIVE
	if exclusive and _group == null:
		_group = ButtonGroup.new()
	for child in get_children():
		var button := child as Button
		if button == null:
			continue
		button.toggle_mode = true
		button.button_group = _group if exclusive else null


func _on_toggled(on: bool, index: int) -> void:
	option_toggled.emit(index, on)
