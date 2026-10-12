class_name TaVBar
extends PanelContainer

# AGENT: Vertical HUD bar. Caption + ProgressBar fill bottom-to-top.
# INVARIANT: set_value writes the themed ProgressBar. No stats backend. The
# percentage is solid ink split at the fill edge (TaBar rule).
# DO NOT: Autoload. Do not own player health.

## Caption plus a vertical Theme-painted ProgressBar (0–100).

const _Text := preload("res://addons/theme_assist/src/components/bar/ta_bar_text.gd")

var _col: VBoxContainer
var _caption: Label
var _bar: ProgressBar
var _value: _Text


func _init() -> void:
	theme_type_variation = "TaVBar"
	# Tall and narrow: a VBox stretched it into a full-width slab.
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_col = VBoxContainer.new()
	add_child(_col)
	_caption = Label.new()
	_caption.theme_type_variation = "TaCardText"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(_caption)
	_bar = ProgressBar.new()
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.value = 100
	_bar.show_percentage = true
	_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col.add_child(_bar)
	# The percentage crosses the fill edge: split ink, as on TaBar.
	_value = _Text.new()
	_value.attach(_bar)
	refresh_metrics()


func refresh_metrics() -> void:
	if not is_instance_valid(_bar):
		return
	var h := TaLook.metric(TaDefaults.VBAR_MIN_HEIGHT, TaDefaults.PIXEL_VBAR_MIN_HEIGHT)
	var w := TaLook.button_height()
	_bar.custom_minimum_size = Vector2(w, h)


func get_bar() -> ProgressBar:
	return _bar


func set_caption(text: String) -> void:
	_caption.text = text


## The percentage as shown ("40%"), or "" when get_bar().show_percentage is off.
func get_value_text() -> String:
	return _value.get_text() if is_instance_valid(_value) else ""


func set_value(amount: float) -> void:
	if is_instance_valid(_bar):
		_bar.value = clampf(amount, _bar.min_value, _bar.max_value)
	if is_instance_valid(_value):
		_value.sync()
