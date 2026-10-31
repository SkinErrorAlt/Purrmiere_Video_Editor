shader_type canvas_item;
render_mode blend_disabled;

const float GRID_X = 8.0;
const float GRID_Y = 4.0;

void fragment() {
	float ysum = 0.0;
	float wsum = 0.0;
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 8; i++) {
			vec4 t = texelFetch(TEXTURE, clamp(ivec2(floor(((vec2(float(i), float(j)) + 0.5) / vec2(GRID_X, GRID_Y)) * vec2(textureSize(TEXTURE, 0)))), ivec2(0), textureSize(TEXTURE, 0) - 1), 0);
			ysum += t.r * t.r * t.g;
			wsum += t.g;
		}
	}
	float mean_y = wsum > 0.000001 ? ysum / wsum : 0.0;
	COLOR = vec4(sqrt(clamp(mean_y, 0.0, 1.0)), clamp(wsum / 32.0 * 20.0, 0.0, 1.0), 0.0, 1.0);
}
