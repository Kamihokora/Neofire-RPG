class_name TaFieldRow
extends HBoxContainer

# AGENT: One labeled field row. Inspector uses many of these; this is the primitive.
# INVARIANT: set_field places the caller's Control. Caption width follows look.
# DO NOT: Bind a property database. Do not autoload.

## Caption plus a field. Use in options/inspect without a full TaInspector.

@export var caption: String = "":
	set(value):
		caption = value
		_apply_caption()

var _label: Label
var _field: Control


func _init() -> void:
	theme_type_variation = "TaFieldRow"
	_label = Label.new()
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	_apply_caption()
	refresh_metrics()


func refresh_metrics() -> void:
	var caption_w := TaLook.metric(
			TaDefaults.INSPECTOR_CAPTION_WIDTH, TaDefaults.PIXEL_INSPECTOR_CAPTION_WIDTH
	)
	if is_instance_valid(_label):
		_label.custom_minimum_size.x = caption_w


func get_field() -> Control:
	return _field


func set_field(field: Control) -> void:
	if is_instance_valid(_field) and _field.get_parent() == self:
		remove_child(_field)
	_field = field
	if is_instance_valid(_field):
		_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(_field)


func _apply_caption() -> void:
	if is_instance_valid(_label):
		_label.text = caption
