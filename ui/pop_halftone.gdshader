shader_type canvas_item;
render_mode unshaded;

uniform vec4 paper : source_color = vec4(0.92, 0.12, 0.25, 1.0);
uniform vec4 ink : source_color = vec4(0.06, 0.05, 0.08, 1.0);
uniform float spacing = 8.0;
uniform float dot_radius : hint_range(0.05, 0.5) = 0.2;

void fragment() {
	vec2 point = SCREEN_UV / SCREEN_PIXEL_SIZE / spacing;
	float distance_to_dot = length(fract(point) - vec2(0.5));
	float coverage = 1.0 - smoothstep(dot_radius - 0.025, dot_radius + 0.025, distance_to_dot);
	COLOR = mix(paper, ink, coverage) * COLOR;
}
