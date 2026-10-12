class_name TaCompass
extends PanelContainer

# AGENT: Bearing + objective marker. Canvas HUD, not a navmesh.
# INVARIANT: set_bearing degrees. Marker is optional extra tick.
# DO NOT: Own the camera or world.

## N/E/S/W ring. set_bearing / set_marker in degrees.

var _stack: Control
var _n: Label
var _needle: ColorRect
var _mark: ColorRect


func _init() -> void:
	theme_type_variation = "TaCompass"
	# A dial is square: stretched wide, the "N" centred on the width while the needle
	# stayed at half the minimum width, far to the left.
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stack = Control.new()
	_stack.resized.connect(_paint)
	add_child(_stack)
	_n = Label.new()
	_n.theme_type_variation = "TaCardText"
	_n.text = "N"
	_n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_n.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_stack.add_child(_n)
	_needle = ColorRect.new()
	_stack.add_child(_needle)
	_mark = ColorRect.new()
	_stack.add_child(_mark)
	refresh_metrics()
	_paint()
	set_bearing(0.0)
	set_marker(45.0)


func refresh_metrics() -> void:
	var s := TaLook.metric(TaDefaults.COMPASS_SIZE, TaDefaults.PIXEL_COMPASS_SIZE)
	custom_minimum_size = Vector2(s, s)
	if is_instance_valid(_stack):
		_stack.custom_minimum_size = Vector2(s, s)
	# Needle geometry and colours follow the new size and look (Pixel is 56, not 88).
	if is_instance_valid(_needle) and is_instance_valid(_mark):
		_paint()


func set_bearing(degrees: float) -> void:
	if is_instance_valid(_needle):
		_needle.rotation_degrees = degrees


func set_marker(degrees: float) -> void:
	if is_instance_valid(_mark):
		_mark.rotation_degrees = degrees
		_mark.visible = true


## Needle and marker around the centre of the dial as laid out (the minimum size until
## the first layout).
func _paint() -> void:
	if not is_instance_valid(_needle) or not is_instance_valid(_mark):
		return
	var look := TaLook.current()
	_needle.color = look.color_accent
	_mark.color = look.color_warning
	var area := _stack.size if _stack.size.x > 0.0 else custom_minimum_size
	var center := area * 0.5
	var s := minf(area.x, area.y)
	_needle.size = Vector2(3, s * 0.35)
	_needle.position = Vector2(center.x - 1.5, center.y - s * 0.35)
	_needle.pivot_offset = Vector2(1.5, s * 0.35)
	_mark.size = Vector2(4, 8)
	_mark.position = Vector2(center.x - 2.0, center.y - s * 0.5 + 4)
	_mark.pivot_offset = Vector2(2, s * 0.5 - 4)
