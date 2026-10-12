class_name TaDimmer
extends ColorRect

# AGENT: Modal dim behind pause/dialog. Juice layer, not a router.
# INVARIANT: IGNORE when idle. fade_in STOP. Not a registry type. dimmer_blur > 0
# uses the kit blur material. A material the caller set is never replaced or cleared.
# DO NOT: Autoload.

const NODE_NAME := "_TaDimmer"

static var _shader: Shader

var _fade: Tween
## The blur material this dimmer made. Only this one is ever swapped or cleared.
var _own_blur: ShaderMaterial


func _init() -> void:
	name = NODE_NAME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	color = Color(0, 0, 0, 1)
	modulate = Color(1, 1, 1, 0)
	z_index = 8


## One dimmer per host name. The default name is shared.
## Pass a key when a second overlay on the same host needs its own dimmer.
static func on(host: Control, key: String = "") -> TaDimmer:
	if not is_instance_valid(host):
		return null
	var node_name := NODE_NAME if key.is_empty() else "%s_%s" % [NODE_NAME, key.validate_node_name()]
	var existing := host.get_node_or_null(node_name)
	if existing is TaDimmer:
		return existing as TaDimmer
	var dim := TaDimmer.new()
	dim.name = node_name
	host.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return dim


## Veil in. alpha / blur below 0 use the look (dimmer_alpha, dimmer_blur); pass
## values for one lighter or sharper veil (a phone in your hand over a readable scene).
func fade_in(alpha: float = -1.0, blur_px: float = -1.0) -> void:
	_kill_fade()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	color = Color(0, 0, 0, 1)
	var target := _alpha() if alpha < 0.0 else clampf(alpha, 0.0, 1.0)
	var blur := _blur() if blur_px < 0.0 else blur_px
	# A material the caller set (their own backdrop) stays; it dims by alpha as usual.
	if material == null or material == _own_blur:
		if blur > 0.0:
			# The shader does the dim so the blur fades in with it.
			_use_blur(blur, target)
			target = 1.0
		else:
			material = null
	if TaJuice.is_reduced():
		modulate.a = target
		return
	_fade = TaJuice.fade_alpha(self, target)
	if _fade == null:
		modulate.a = target


func fade_out() -> void:
	_kill_fade()
	# Drop STOP immediately so a hidden popup cannot soft-lock the game.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if TaJuice.is_reduced():
		modulate.a = 0.0
		visible = false
		return
	_fade = TaJuice.fade_alpha(self, 0.0)
	if _fade:
		_fade.finished.connect(
			func() -> void:
				mouse_filter = Control.MOUSE_FILTER_IGNORE
				visible = false
		)
	else:
		modulate.a = 0.0
		visible = false


func _blur() -> float:
	return maxf(0.0, TaLook.current().dimmer_blur)


func _use_blur(radius: float, dim: float) -> void:
	if _own_blur == null:
		_own_blur = ShaderMaterial.new()
		_own_blur.shader = _blur_shader()
	var mat := _own_blur
	material = mat
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("dim", dim)


static func _blur_shader() -> Shader:
	if _shader != null:
		return _shader
	_shader = Shader.new()
	_shader.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float radius = 0.0;
uniform float dim = 0.65;
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * radius;
	vec3 sum = vec3(0.0);
	float weight = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float w = 1.0 / (1.0 + float(x * x + y * y));
			sum += texture(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * px * 0.5).rgb * w;
			weight += w;
		}
	}
	COLOR = vec4(mix(sum / weight, vec3(0.0), dim), 1.0);
}
"""
	return _shader


func _alpha() -> float:
	return TaLook.current().dimmer_alpha


func _kill_fade() -> void:
	if _fade != null:
		_fade.kill()
		_fade = null
