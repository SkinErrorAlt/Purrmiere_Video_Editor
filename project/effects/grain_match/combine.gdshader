shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D clip_cells : filter_nearest, repeat_disable;
uniform sampler2D ref_cells : filter_nearest, repeat_disable;

const float GRID_X = 8.0;
const float GRID_Y = 4.0;

float robust(sampler2D cells, out float valid) {
	float v[32];
	float ok[32];
	float count = 0.0;
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 8; i++) {
			vec4 t = textureLod(cells, (vec2(float(i), float(j)) + 0.5) / vec2(GRID_X, GRID_Y), 0.0);
			v[j * 8 + i] = t.r;
			ok[j * 8 + i] = t.g;
			count += t.g > 0.5 ? 1.0 : 0.0;
		}
	}
	valid = count > 0.0 ? 1.0 : 0.0;
	float keep = max(ceil(count * 0.375), 1.0);
	float sum = 0.0;
	float n = 0.0;
	for (int i = 0; i < 32; i++) {
		if (ok[i] < 0.5) {
			continue;
		}
		float below = 0.0;
		for (int k = 0; k < 32; k++) {
			if (ok[k] > 0.5 && (v[k] < v[i] || (v[k] == v[i] && k < i))) {
				below += 1.0;
			}
		}
		if (below < keep) {
			sum += v[i];
			n += 1.0;
		}
	}
	return n > 0.0 ? sum / n : 0.0;
}

void fragment() {
	float clip_valid;
	float ref_valid;
	float clip_est = robust(clip_cells, clip_valid);
	float ref_est = robust(ref_cells, ref_valid);
	float k = sqrt(3.1415927 * 0.5) / 6.0 / 2.5 * 1.81;
	COLOR = vec4(clamp(clip_est * k * 10.0, 0.0, 1.0), clamp(ref_est * k * 10.0, 0.0, 1.0), ref_valid, 1.0);
}
