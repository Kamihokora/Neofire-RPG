class_name TaCrtOverlay
extends CanvasLayer

# AGENT: Scanline/CRT layer used only by the pixel look. Core, not a widget.
# INVARIANT: Not in TaRegistry. apply_to adds/removes this by node name.
# DO NOT: Register as a custom type. Do not intercept mouse input.

const NODE_NAME := "_TaCrtOverlay"


func _init() -> void:
	name = NODE_NAME
	layer = 100
	var rect := ColorRect.new()
	rect.name = "Scanlines"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	rect.color = Color(0, 0, 0, 0)
	rect.material = _make_material()
	add_child(rect)


static func sync_on(control: Control, enabled: bool, intensity: float = -1.0) -> void:
	if not is_instance_valid(control):
		return
	var existing := control.get_node_or_null(NODE_NAME)
	var level := intensity
	if level < 0.0:
		level = TaDefaults.CRT_INTENSITY
	var want := enabled and not TaJuice.is_reduced() and level > 0.0001
	if want:
		var overlay: TaCrtOverlay = existing as TaCrtOverlay
		if overlay == null:
			overlay = TaCrtOverlay.new()
			control.add_child(overlay)
		overlay.set_intensity(level)
		return
	if existing != null:
		existing.free()


func set_intensity(value: float) -> void:
	var rect := get_node_or_null("Scanlines") as ColorRect
	if rect != null and rect.material is ShaderMaterial:
		(rect.material as ShaderMaterial).set_shader_parameter("intensity", value)


static func _make_material() -> ShaderMaterial:
	var shader := Shader.new()
	var tint := TaDefaults.CRT_TINT
	shader.code = """shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform float intensity : hint_range(0.0, 1.0) = 0.22;
uniform float line_count : hint_range(60.0, 720.0) = 240.0;
uniform vec3 tint = vec3(0.02, 0.04, 0.03);
void fragment() {
	float scan = abs(fract(UV.y * line_count) - 0.5) * 2.0;
	float dark = mix(intensity, 0.0, scan);
	vec2 centered = UV * 2.0 - 1.0;
	float vig = dot(centered, centered) * 0.12 * intensity;
	COLOR = vec4(tint, clamp(dark + vig, 0.0, 0.45));
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("intensity", TaDefaults.CRT_INTENSITY)
	material.set_shader_parameter("line_count", TaDefaults.CRT_LINE_COUNT)
	material.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	return material
