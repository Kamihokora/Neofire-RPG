class_name TaBanner
extends PanelContainer

# AGENT: Wave / round / countdown banner. Typography, not a timer backend.
# INVARIANT: set_title + set_sub. Display only.
# DO NOT: Own a wave loop.

## "WAVE 3" + "12" countdown (or any subtitle).

var _col: VBoxContainer
var _title: Label
var _sub: Label


func _init() -> void:
	theme_type_variation = "TaBanner"
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", TaLook.metric(2, 1))
	add_child(_col)
	_title = Label.new()
	_title.theme_type_variation = "TaTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(_title)
	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(_sub)


func set_title(text: String) -> void:
	_title.text = text


func set_sub(text: String) -> void:
	_sub.text = text
