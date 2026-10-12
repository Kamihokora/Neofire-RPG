class_name TaPromptHint
extends Label

# AGENT: Keyboard/gamepad prompt strip. Presentation only.
# INVARIANT: Captions come from InputMap + last device. Not a remap manager.
# DO NOT: Autoload. Do not own remapping.

## "Esc Back  |  Enter Confirm" or joypad captions from InputMap.

var _gamepad: bool = false
var _cancel_act: String = "Back"
var _ok_act: String = "Confirm"


func _init() -> void:
	theme_type_variation = "TaPromptHint"
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh_from_map()


func _ready() -> void:
	set_process_input(true)
	refresh_from_map()


func set_prompts(cancel_key: String, cancel_act: String, ok_key: String, ok_act: String) -> void:
	_cancel_act = cancel_act
	_ok_act = ok_act
	text = "%s %s  |  %s %s" % [cancel_key, cancel_act, ok_key, ok_act]


func set_gamepad(on: bool) -> void:
	_gamepad = on
	refresh_from_map()


func refresh_from_map() -> void:
	var cancel_key := _caption_for(&"ui_cancel")
	var ok_key := _caption_for(&"ui_accept")
	set_prompts(cancel_key, _cancel_act, ok_key, _ok_act)


## _input, not _unhandled_input: a focused menu consumes D-pad and A presses first,
## so the hint never saw the gamepad in the one place it is shown. Never consumes.
func _input(event: InputEvent) -> void:
	var pad: bool = event is InputEventJoypadButton and event.pressed
	if event is InputEventJoypadMotion:
		pad = absf((event as InputEventJoypadMotion).axis_value) >= TaDefaults.PROMPT_STICK_DEADZONE
	if pad:
		if not _gamepad:
			_gamepad = true
			refresh_from_map()
	elif (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		if _gamepad:
			_gamepad = false
			refresh_from_map()


func _caption_for(action: StringName) -> String:
	if not InputMap.has_action(action):
		return _fallback(action)
	if _gamepad:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				return _joy_name((event as InputEventJoypadButton).button_index)
		return _fallback(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			if key.keycode == KEY_ESCAPE:
				return "Esc"
			if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
				return "Enter"
			return key.as_text().replace(" (Physical)", "")
	return _fallback(action)


func _fallback(action: StringName) -> String:
	if _gamepad:
		return "B" if action == &"ui_cancel" else "A"
	return "Esc" if action == &"ui_cancel" else "Enter"


func _joy_name(button_index: int) -> String:
	match button_index:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_BACK:
			return "Back"
		_:
			return "Btn%d" % button_index
