class_name TaReticle
extends Control

# AGENT: Center crosshair + hitmarker. Canvas overlay, not a weapon system.
# INVARIANT: mouse_filter IGNORE. ping_hit flashes the marker.
# DO NOT: Own hitscan. Do not autoload.

## Full-rect overlay. Place on the HUD root.

var _cross: Label
var _hit: Label


func _init() -> void:
	theme_type_variation = "TaReticle"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_cross = Label.new()
	_cross.text = "+"
	_cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cross)
	_hit = Label.new()
	_hit.text = "x"
	_hit.theme_type_variation = "TaDangerLabel"
	_hit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit.modulate.a = 0.0
	add_child(_hit)


func ping_hit() -> void:
	if not is_instance_valid(_hit):
		return
	_hit.modulate.a = 1.0
	if TaJuice.is_reduced():
		# Drop the fade, keep the information: show the mark for the open time.
		if is_inside_tree():
			get_tree().create_timer(TaJuice.open_seconds).timeout.connect(
				func() -> void:
					if is_instance_valid(_hit):
						_hit.modulate.a = 0.0
			)
		else:
			_hit.modulate.a = 0.0
		return
	var tween := create_tween()
	tween.tween_property(_hit, "modulate:a", 0.0, TaJuice.press_seconds)
