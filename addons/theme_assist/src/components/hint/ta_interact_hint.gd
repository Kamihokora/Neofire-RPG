class_name TaInteractHint
extends HBoxContainer

# AGENT: World interact keychip. Not the menu Esc|Enter strip (TaPromptHint).
# INVARIANT: set_prompt(key, action) is "[E] Open chest". Canvas only.
# DO NOT: Bind InputMap. Do not persist. Do not world-space billboard.

## Single-action world prompt. Separate from TaPromptHint.

@export var key: String = "E":
	set(value):
		key = value
		_apply()

@export var action: String = "Interact":
	set(value):
		action = value
		_apply()

## Over the game world (the usual place): the action is light ink with a dark halo
## (TaSceneText), readable over a night or a snow scene. False for a hint inside a panel:
## plain body ink, like the text around it.
@export var on_scene: bool = true:
	set(value):
		on_scene = value
		_apply()

var _keycap: PanelContainer
var _key_label: Label
var _action: Label


func _init() -> void:
	theme_type_variation = "TaInteractHint"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keycap = PanelContainer.new()
	_keycap.theme_type_variation = "TaKeycap"
	add_child(_keycap)
	_key_label = Label.new()
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_keycap.add_child(_key_label)
	_action = Label.new()
	_action.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_action)
	_apply()
	refresh_metrics()


func refresh_metrics() -> void:
	var cell := TaLook.metric(TaDefaults.KEYCAP_MIN, TaDefaults.PIXEL_KEYCAP_MIN)
	if is_instance_valid(_keycap):
		_keycap.custom_minimum_size = Vector2(cell, cell)


func set_prompt(next_key: String, next_action: String) -> void:
	key = next_key
	action = next_action


func _apply() -> void:
	if is_instance_valid(_key_label):
		_key_label.text = key
	if is_instance_valid(_action):
		_action.text = action
		_action.theme_type_variation = &"TaSceneText" if on_scene else &""
