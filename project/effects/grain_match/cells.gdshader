shader_type canvas_item;
render_mode blend_disabled;

const float GRID_X = 8.0;
const float GRID_Y = 4.0;
const int STEPS = 16;

void fragment() {
	vec2 grid = vec2(GRID_X, GRID_Y);
	vec2 cell = min(floor(UV * grid), grid - 1.0);
	float lo = 1.0;
	float sum = 0.0;
	float count = 0.0;
	for (int j = 0; j < STEPS; j++) {
		for (int i = 0; i < STEPS; i++) {
			vec4 t = texelFetch(TEXTURE, clamp(ivec2(floor(((cell + (vec2(float(i), float(j)) + 0.5) / float(STEPS)) / grid) * vec2(textureSize(TEXTURE, 0)))), ivec2(0), textureSize(TEXTURE, 0) - 1), 0);
			if (t.g > 0.5) {
				lo = min(lo, t.r);
				sum += t.r;
				count += 1.0;
			}
		}
	}
	if (count < 8.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		float mean = sum / count;
		float cut = lo + (mean - lo) * 0.5;
		float low_sum = 0.0;
		float low_n = 0.0;
		for (int j = 0; j < STEPS; j++) {
			for (int i = 0; i < STEPS; i++) {
				vec4 t = texelFetch(TEXTURE, clamp(ivec2(floor(((cell + (vec2(float(i), float(j)) + 0.5) / float(STEPS)) / grid) * vec2(textureSize(TEXTURE, 0)))), ivec2(0), textureSize(TEXTURE, 0) - 1), 0);
				if (t.g > 0.5 && t.r <= cut + 0.00001) {
					low_sum += t.r;
					low_n += 1.0;
				}
			}
		}
		COLOR = vec4(low_n > 0.0 ? low_sum / low_n : 0.0, 1.0, 0.0, 1.0);
	}
}
