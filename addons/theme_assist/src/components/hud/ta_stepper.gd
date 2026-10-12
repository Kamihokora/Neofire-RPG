class_name TaStepper
extends HBoxContainer

# AGENT: Minus / value / plus. Bets, stacks, counts. Display + local value only.
# INVARIANT: value_changed emits the int. Not a wallet.
# DO NOT: Persist. Do not own currency.

## Stake / count stepper.

signal value_changed(value: int)

var _minus: Button
var _label: Label
var _plus: Button
var _value: int = 1
var _min: int = TaDefaults.STEPPER_MIN
var _max: int = TaDefaults.STEPPER_MAX


func _init() -> void:
	theme_type_variation = "TaStepper"
	# Compact: a tall row stretched the buttons into 26 x 90 px slivers.
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_minus = TaButton.new()
	_minus.text = "-"
	_minus.pressed.connect(func() -> void: set_value(_value - 1))
	add_child(_minus)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	_plus = TaButton.new()
	_plus.text = "+"
	_plus.pressed.connect(func() -> void: set_value(_value + 1))
	add_child(_plus)
	refresh_metrics()
	_sync()


func _ready() -> void:
	TaJuice.bind_hover(_minus)
	TaJuice.bind_hover(_plus)


## Square buttons: as wide as they are tall (look.button_min_height, or taller when
## the font needs it), and a value column as wide. They were narrower than tall.
func refresh_metrics() -> void:
	var look := TaLook.current()
	var h := float(TaLook.button_height())
	for button in [_minus, _plus]:
		if is_instance_valid(button):
			h = maxf(h, (button as Button).get_minimum_size().y)
	for button in [_minus, _plus]:
		if is_instance_valid(button):
			(button as Button).custom_minimum_size = Vector2(h, h)
	if is_instance_valid(_label):
		_label.custom_minimum_size.x = h


func _notification(what: int) -> void:
	# The buttons take their font after this node hears the change: measure afterwards.
	if what == NOTIFICATION_THEME_CHANGED:
		call_deferred("refresh_metrics")


func set_limits(minimum: int, maximum: int) -> void:
	_min = minimum
	_max = maxi(minimum, maximum)
	set_value(_value)


func set_value(next: int) -> void:
	var clamped := clampi(next, _min, _max)
	var changed := clamped != _value
	_value = clamped
	_sync()
	if changed:
		value_changed.emit(_value)


func get_value() -> int:
	return _value


func _sync() -> void:
	if is_instance_valid(_label):
		_label.text = str(_value)
	if is_instance_valid(_minus):
		_minus.disabled = _value <= _min
	if is_instance_valid(_plus):
		_plus.disabled = _value >= _max
