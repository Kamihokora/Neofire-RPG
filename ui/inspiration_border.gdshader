shader_type canvas_item;
render_mode unshaded;
uniform vec2 box_size = vec2(280.0, 92.0);
uniform vec4 paper : source_color = vec4(1.0);
uniform bool selected = false;
uniform bool invalid_pair = false;

void fragment() {
	float radius = 19.0;
	vec2 point = abs(UV * box_size - box_size * 0.5) - (box_size * 0.5 - vec2(radius + 2.0));
	float distance_to_edge = length(max(point, vec2(0.0))) + min(max(point.x, point.y), 0.0) - radius;
	float edge = smoothstep(selected ? -6.0 : -4.0, selected ? -4.0 : -2.0, distance_to_edge);
	vec3 gold = mix(vec3(1.0, 0.96, 0.64), vec3(0.83, 0.48, 0.06), clamp(UV.y + UV.x * 0.25, 0.0, 1.0));
	vec3 stroke = invalid_pair ? vec3(0.92, 0.10, 0.23) : (selected ? gold : vec3(0.06));
	COLOR = vec4(mix(paper.rgb, stroke, edge), 1.0 - smoothstep(-1.0, 1.0, distance_to_edge));
}
