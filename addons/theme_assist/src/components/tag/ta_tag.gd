class_name TaTag
extends PanelContainer

# AGENT: Label tag, optional dismiss. Component layer.
# INVARIANT: dismiss() hides and emits dismissed. Does not queue_free.
# DO NOT: Invent colors. Tone maps to Theme variations.

## Status label by default. Set dismissible true for a removable chip.
## dismiss() hides; it does not free the node.

signal dismissed

enum Tone {
	DEFAULT,
	ACCENT,
	MUTED,
	DANGER,
	SUCCESS,
	WARNING,
	RARITY,
}

@export var text: String = "":
	set(value):
		text = value
		_apply_text()

@export var tone: Tone = Tone.DEFAULT:
	set(value):
		tone = value
		_apply_tone()

## A tone from look.tones ("money"). Wins over tone while not empty.
@export var tone_name: String = "":
	set(value):
		tone_name = value
		_apply_tone()

@export var dismissible: bool = false:
	set(value):
		dismissible = value
		_apply_dismiss()

var _row: HBoxContainer
var _label: Label
var _close: Button
var _painting: bool = false


func _init() -> void:
	# A tag is inline: stretched by a VBox or a tall row it became a full-width pill.
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row = HBoxContainer.new()
	add_child(_row)
	_label = Label.new()
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_row.add_child(_label)
	_close = TaButton.new()
	_close.text = TaDefaults.TAG_DISMISS
	_close.theme_type_variation = "TaTagClose"
	_close.pressed.connect(dismiss)
	_row.add_child(_close)
	_apply_text()
	_apply_tone()
	_apply_dismiss()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_PARENTED:
		_paint_ink()


func _ready() -> void:
	_paint_ink()
	TaJuice.bind_hover(_close)


func dismiss() -> void:
	visible = false
	dismissed.emit()


func _apply_text() -> void:
	if is_instance_valid(_label):
		_label.text = text


func _apply_tone() -> void:
	if not tone_name.is_empty():
		theme_type_variation = TaThemeBuilder.tone_type("TaTag", tone_name)
		_paint_ink()
		return
	match tone:
		Tone.ACCENT:
			theme_type_variation = "TaTagAccent"
		Tone.MUTED:
			theme_type_variation = "TaTagMuted"
		Tone.DANGER:
			theme_type_variation = "TaTagDanger"
		Tone.SUCCESS:
			theme_type_variation = "TaTagSuccess"
		Tone.WARNING:
			theme_type_variation = "TaTagWarning"
		Tone.RARITY:
			theme_type_variation = "TaTagRarity"
		_:
			theme_type_variation = "TaTag"
	_paint_ink()


## The tone's ink from the nearest Theme that has it (see TaBadge._paint_ink).
func _paint_ink() -> void:
	if _painting or not is_instance_valid(_label):
		return
	var type_name := StringName(theme_type_variation)
	var source := TaThemeBuilder.theme_with_color(self, "font_color", type_name)
	if source == null or type_name.is_empty():
		return
	_painting = true
	var ink := source.get_color("font_color", type_name)
	TaThemeBuilder.paint_label(_label, source, type_name)
	# The dismiss glyph wears the tag ink and size, so it reads as part of the tag.
	for item in [
		"font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
		"font_hover_pressed_color",
	]:
		_close.add_theme_color_override(item, ink)
	if source.has_font_size("font_size", type_name):
		var size := source.get_font_size("font_size", type_name)
		if size > 0:
			_close.add_theme_font_size_override("font_size", size)
	if source.has_font("font", type_name):
		_close.add_theme_font_override("font", source.get_font("font", type_name))
	_painting = false


func _apply_dismiss() -> void:
	if is_instance_valid(_close):
		_close.visible = dismissible
