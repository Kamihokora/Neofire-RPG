shader_type canvas_item;
render_mode unshaded;

uniform float blur_amount : hint_range(0.0, 12.0) = 0.0;
varying vec4 item_tint;

void vertex() {
	item_tint = COLOR;
}

void fragment() {
	if (blur_amount < 0.01) {
		COLOR = item_tint * texture(TEXTURE, UV);
	} else {
		vec2 step_uv = TEXTURE_PIXEL_SIZE * blur_amount / 3.0;
		vec4 blurred = vec4(0.0);
		for (int x = -3; x <= 3; x++) {
			for (int y = -3; y <= 3; y++) {
				float weight = float((4 - abs(x)) * (4 - abs(y)));
				blurred += texture(TEXTURE, UV + vec2(float(x), float(y)) * step_uv) * weight;
			}
		}
		COLOR = item_tint * blurred / 256.0;
	}
}
