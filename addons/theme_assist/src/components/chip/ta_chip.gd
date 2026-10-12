class_name TaChip
extends PanelContainer

# AGENT: HUD chip: caption + rolling value + optional badge. Display only.
# INVARIANT: roll() drives TaJuice.roll_number on the value label.
# DO NOT: Own currency backends.

## Small HUD stat. set_value / roll for numbers. set_text for a clock or place name.

var _row: HBoxContainer
var _stack: VBoxContainer
var _icon: TextureRect
var _caption: Label
var _value: Label
var _badge: TaBadge
var _stacked: bool = false


func _init() -> void:
	theme_type_variation = "TaChip"
	# Sized to its text in a VBox too (it keeps filling a row's height, beside a bar).
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_row = HBoxContainer.new()
	_row.name = "Row"
	add_child(_row)
	_icon = TextureRect.new()
	_icon.visible = false
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(TaDefaults.SWATCH_SIZE, TaDefaults.SWATCH_SIZE)
	_row.add_child(_icon)
	_caption = Label.new()
	# A label, not a value: muted, in the caption face (small caps in Framed), in ink that
	# reads on the chip's card (Framed's cream).
	_caption.theme_type_variation = "TaCardCaption"
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_row.add_child(_caption)
	_value = Label.new()
	_value.theme_type_variation = "TaCardText"
	_value.text = "0"
	_row.add_child(_value)
	_badge = TaBadge.new()
	_badge.visible = false
	_row.add_child(_badge)


func set_icon(texture: Texture2D) -> void:
	_icon.texture = texture
	_icon.visible = texture != null


func set_caption(text: String) -> void:
	_caption.text = text


## Caption above the value. Default stays one row.
func set_stacked(on: bool) -> void:
	if _stacked == on:
		return
	_stacked = on
	if on:
		if _stack == null:
			_stack = VBoxContainer.new()
			_stack.name = "Stack"
			_stack.add_theme_constant_override("separation", 0)
		if _stack.get_parent() != self:
			add_child(_stack)
		_row.remove_child(_caption)
		_caption.theme_type_variation = "TaCardCaption"
		_stack.add_child(_caption)
		if _row.get_parent() != null:
			_row.get_parent().remove_child(_row)
		_stack.add_child(_row)
		move_child(_stack, 0)
	else:
		if _caption.get_parent() == _stack:
			_stack.remove_child(_caption)
		_caption.theme_type_variation = "TaCardCaption"
		if _row.get_parent() == _stack:
			_stack.remove_child(_row)
			add_child(_row)
		_row.add_child(_caption)
		_row.move_child(_caption, 1)
		if _stack != null and _stack.get_parent() == self:
			remove_child(_stack)


## Tint the value. A transparent color clears the override.
func set_value_color(color: Color) -> void:
	if color.a <= 0.0:
		_value.remove_theme_color_override("font_color")
	else:
		_value.add_theme_color_override("font_color", color)


func set_badge(text: String) -> void:
	_badge.text = text
	_badge.visible = not text.is_empty()


func set_value(amount: float) -> void:
	_value.text = "%d" % int(round(amount))


## Non-numeric readout. Does not go through roll().
func set_text(value: String) -> void:
	_value.text = value


## Mag/reserve or dual currency: "30 / 90".
func set_pair(left: float, right: float) -> void:
	_value.text = "%d / %d" % [int(round(left)), int(round(right))]


func roll(to_value: float, from_value: float = NAN) -> void:
	TaJuice.roll_number(_value, to_value, from_value)
