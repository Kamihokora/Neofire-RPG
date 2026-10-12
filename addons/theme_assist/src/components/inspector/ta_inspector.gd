class_name TaInspector
extends PanelContainer

# AGENT: Labeled rows for options/inspect. Component layer.
# INVARIANT: add_row returns the row. Fields stay the caller's nodes. Every caption
# is as wide as the widest (at least the look's caption width), so fields line up.
# DO NOT: Bind a property database. Do not autoload.

## Vertical inspector. add_row(caption, field) for options screens.

var _list: VBoxContainer
var _align_queued: bool = false


func _init() -> void:
	theme_type_variation = "TaInspector"
	_list = VBoxContainer.new()
	add_child(_list)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_queue_align()


func refresh_metrics() -> void:
	_queue_align()


func get_list() -> VBoxContainer:
	return _list


func add_row(caption: String, field: Control, help: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = caption
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	if is_instance_valid(field):
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(field)
	if not help.is_empty():
		row.tooltip_text = help
		label.tooltip_text = help
		if is_instance_valid(field):
			field.tooltip_text = help
	_list.add_child(row)
	_queue_align()
	return row


## Measure at the end of the frame: labels take their font when they enter the tree,
## after this node hears the theme change.
func _queue_align() -> void:
	if not _align_queued:
		_align_queued = true
		call_deferred("_align_captions")


## One caption column: the widest caption, never less than the look's caption width.
## A fixed width let a long caption push its own field right (Pixel "Reduce motion"
## is 104 px against 56), so the option fields zig-zagged.
func _align_captions() -> void:
	_align_queued = false
	if not is_instance_valid(_list):
		return
	var widest := float(TaLook.metric(
			TaDefaults.INSPECTOR_CAPTION_WIDTH, TaDefaults.PIXEL_INSPECTOR_CAPTION_WIDTH
	))
	var labels: Array[Label] = []
	for row in _list.get_children():
		var label := row.get_child(0) as Label if row.get_child_count() > 0 else null
		if label == null:
			continue
		labels.append(label)
		label.custom_minimum_size.x = 0
		widest = maxf(widest, label.get_minimum_size().x)
	for label in labels:
		label.custom_minimum_size.x = widest
