class_name TaStatRow
extends HBoxContainer

# AGENT: Name + signed value. Green + / red −. Display only.
# INVARIANT: set_stat(name, delta) picks Success/Danger label.
# DO NOT: Own RPG math.

## One semantic stat line for shop cards and inspect.

var _name: Label
var _value: Label


func _init() -> void:
	theme_type_variation = "TaStatRow"
	_name = Label.new()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_name)
	_value = Label.new()
	add_child(_value)


func set_stat(stat_name: String, delta: float, absolute: bool = false) -> void:
	_name.text = stat_name
	if absolute:
		_value.text = "%d" % int(round(delta))
		_value.theme_type_variation = ""
		return
	var sign := "+" if delta >= 0.0 else ""
	_value.text = "%s%d" % [sign, int(round(delta))]
	if delta > 0.0:
		_value.theme_type_variation = "TaSuccessLabel"
	elif delta < 0.0:
		_value.theme_type_variation = "TaDangerLabel"
	else:
		_value.theme_type_variation = "TaCaption"
