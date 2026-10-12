@tool
class_name TaBar
extends PanelContainer

# AGENT: HUD HP/XP-style bar. Caption + ProgressBar. Optional cur/max label.
# INVARIANT: set_value is 0–100. set_range writes current/maximum text. The value
# text (range or percentage) is solid ink split at the fill edge, 4.5:1 on each part.
# DO NOT: Autoload. Do not own player health. Do not outline the value (1.11 rule:
# page-colour digits turned hollow over the empty track).

## Caption plus a Theme-painted ProgressBar. Use set_range for "72/100".

const _Text := preload("res://addons/theme_assist/src/components/bar/ta_bar_text.gd")

var _row: HBoxContainer
var _caption: Label
var _stack: Control
var _bar: ProgressBar
var _value: _Text
var _current: float = 100.0
var _maximum: float = 100.0
var _show_range: bool = false


func _init() -> void:
	theme_type_variation = "TaBar"
	_row = HBoxContainer.new()
	add_child(_row)
	_caption = Label.new()
	_caption.theme_type_variation = "TaCardText"
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_row.add_child(_caption)
	_stack = Control.new()
	_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(_stack)
	_bar = ProgressBar.new()
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.value = 100
	_bar.show_percentage = true
	_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stack.add_child(_bar)
	_value = _Text.new()
	_value.attach(_bar)
	refresh_metrics()


func refresh_metrics() -> void:
	if not is_instance_valid(_stack):
		return
	var h := TaLook.button_height()
	# Room for the value at this display's type size: a fixed 80 px dropped "72/100" on
	# Pixel nameplates (the text hides when it does not fit) and shrank at 4K.
	var w := maxi(
			TaLook.metric(TaDefaults.BAR_MIN_WIDTH, TaDefaults.PIXEL_BAR_MIN_WIDTH), _value_room()
	)
	_stack.custom_minimum_size = Vector2(w, h)
	if is_instance_valid(_bar):
		_bar.custom_minimum_size = Vector2(w, h)
	if is_instance_valid(_value):
		_value.sync()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		refresh_metrics()


## Width that holds the widest value ("100/100", "100%") wholly in the fill or the empty
## track at any value, so the value never straddles the fill edge. 0 off-tree or with no
## value text.
func _value_room() -> int:
	if not is_instance_valid(_bar) or not is_inside_tree():
		return 0
	var widest := ""
	if _show_range:
		widest = "%d/%d" % [int(round(_maximum)), int(round(_maximum))]
	elif _bar.show_percentage:
		widest = "100%"
	var font := _bar.get_theme_font("font")
	if widest.is_empty() or font == null:
		return 0
	var wide := font.get_string_size(
			widest, HORIZONTAL_ALIGNMENT_LEFT, -1, _bar.get_theme_font_size("font_size")
	).x
	var track := _bar.get_theme_stylebox("background")
	var frame := track.get_minimum_size().x if track != null else 0.0
	return ceili(wide * _Text.ROOM + frame)


func get_bar() -> ProgressBar:
	return _bar


func set_caption(text: String) -> void:
	_caption.text = text


func set_value(amount: float) -> void:
	if is_instance_valid(_bar):
		_bar.value = clampf(amount, _bar.min_value, _bar.max_value)
	if is_instance_valid(_value):
		_value.sync()


func set_range(current: float, maximum: float) -> void:
	_show_range = true
	_current = current
	_maximum = maxf(1.0, maximum)
	if is_instance_valid(_bar):
		_bar.show_percentage = false
		_bar.value = clampf((_current / _maximum) * 100.0, 0.0, 100.0)
	if is_instance_valid(_value):
		_value.text = "%d/%d" % [int(round(_current)), int(round(_maximum))]
	refresh_metrics()


func get_range_text() -> String:
	return _value.text if is_instance_valid(_value) else ""


## The value text as shown: "180/480", "72%", or "" when there is none.
func get_value_text() -> String:
	return _value.get_text() if is_instance_valid(_value) else ""
