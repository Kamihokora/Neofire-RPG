shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	vec2 step_uv = TEXTURE_PIXEL_SIZE * 7.0;
	float halo = 0.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.785398;
		halo += texture(TEXTURE, UV + vec2(cos(angle), sin(angle)) * step_uv).a;
	}
	float edge = max(halo * 0.125 - art.a, 0.0) * flash;
	COLOR = vec4(mix(art.rgb, vec3(1.7), flash), max(art.a, edge * 0.8)) * vertex_tint;
}
