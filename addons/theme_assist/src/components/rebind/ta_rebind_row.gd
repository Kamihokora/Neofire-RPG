class_name TaRebindRow
extends HBoxContainer

# AGENT: One-action rebind row. Presentation Control, not a remap manager.
# INVARIANT: Replaces the first keyboard event only. Joypad binds stay.
# DO NOT: Autoload. Do not erase all InputMap events. Do not persist.

## Click the button, then press a key to rebind `action`. Escape cancels.
## caption is the player-facing name. Empty hides it (a TaInspector row already names it).

signal rebound(action: StringName, event: InputEvent)

@export var action: StringName = &"ui_accept"
@export var caption: String = "":
	set(value):
		caption = value
		_refresh()

var _label: Label
var _button: Button
var _listening: bool = false
var _timer: Timer


func _init() -> void:
	_label = Label.new()
	_label.custom_minimum_size.x = TaLook.metric(
			TaDefaults.INSPECTOR_CAPTION_WIDTH, TaDefaults.PIXEL_INSPECTOR_CAPTION_WIDTH
	)
	add_child(_label)
	_button = TaButton.new()
	_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button.pressed.connect(_on_pressed)
	add_child(_button)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)
	_refresh()


func _ready() -> void:
	set_process_input(true)
	TaJuice.bind_hover(_button)
	_refresh()


## _input while listening: a key capture must see the key before menus, the
## TaCancelRouter, or the focused button do (Esc cancels the listen, nothing else).
func _input(event: InputEvent) -> void:
	if not _listening:
		return
	if not is_visible_in_tree():
		_cancel()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE:
			_cancel()
			get_viewport().set_input_as_handled()
			return
		apply_key_event(key)
		get_viewport().set_input_as_handled()


func is_listening() -> bool:
	return _listening


func cancel_listen() -> void:
	_cancel()


## Replace the first keyboard event on `action`. Keep joypad/mouse binds.
func apply_key_event(event: InputEventKey) -> void:
	_listening = false
	_timer.stop()
	if not InputMap.has_action(action):
		_refresh()
		return
	var stored := event.duplicate() as InputEventKey
	stored.pressed = false
	stored.echo = false
	var kept: Array[InputEvent] = []
	var replaced := false
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and not replaced:
			kept.append(stored)
			replaced = true
		else:
			kept.append(existing)
	if not replaced:
		kept.append(stored)
	InputMap.action_erase_events(action)
	for keep in kept:
		InputMap.action_add_event(action, keep)
	rebound.emit(action, event)
	_refresh()


func _on_pressed() -> void:
	_listening = true
	_button.text = "Press a key..."
	_timer.start(TaDefaults.REBIND_LISTEN_SECONDS)


func _on_timeout() -> void:
	if _listening:
		_cancel()


func _cancel() -> void:
	_listening = false
	_timer.stop()
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(_label) or not is_instance_valid(_button):
		return
	# Players never see "ui_accept". The action name is for code, not the screen.
	_label.text = caption
	_label.visible = not caption.is_empty()
	if not InputMap.has_action(action):
		_button.text = "(none)"
		return
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		_button.text = "(none)"
		return
	for event in events:
		if event is InputEventKey:
			_button.text = event.as_text()
			return
	_button.text = events[0].as_text()
