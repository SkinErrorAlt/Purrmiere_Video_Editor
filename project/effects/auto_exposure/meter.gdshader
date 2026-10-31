shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float centre_weight : hint_range(0.0, 1.0) = 0.5;
uniform int stage = 0;

const float GRID_X = 8.0;
const float GRID_Y = 4.0;
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float log_luma(vec4 s) {
	vec3 rgb = s.a > 0.0001 ? clamp(s.rgb / s.a, 0.0, 1.0) : vec3(0.0);
	float l = dot(pow(rgb, vec3(2.2)), LUMA);
	return clamp((log2(max(l, 0.0002)) + 12.0) / 12.0, 0.0, 1.0);
}

float weight_at(vec2 uv) {
	vec2 d = (uv - 0.5) * vec2(tex_size.x / max(tex_size.y, 1.0), 1.0);
	return mix(1.0, exp(-dot(d, d) * 5.0), clamp(centre_weight, 0.0, 1.0)) * 0.9 + 0.1;
}

void fragment() {
	vec2 src = max(tex_size, vec2(1.0));
	float sum = 0.0;
	float wsum = 0.0;
	int count = 0;
	if (stage == 0) {
		vec2 foot = max(src * SCREEN_PIXEL_SIZE, vec2(1.0));
		int nx = int(clamp(ceil(foot.x), 1.0, 8.0));
		int ny = int(clamp(ceil(foot.y), 1.0, 8.0));
		vec2 stride = foot / vec2(float(nx), float(ny));
		vec2 start = UV * src - foot * 0.5;
		for (int j = 0; j < 8; j++) {
			if (j >= ny) {
				break;
			}
			for (int i = 0; i < 8; i++) {
				if (i >= nx) {
					break;
				}
				vec2 p = start + (vec2(float(i), float(j)) + 0.5) * stride;
				vec2 uv = clamp((floor(p) + 0.5) / src, vec2(0.0), vec2(1.0));
				vec4 s = texture(TEXTURE, uv);
				float w = weight_at(uv) * step(0.0001, s.a);
				sum += log_luma(s) * w;
				wsum += w;
				count += 1;
			}
		}
		float mean_w = wsum / max(float(count), 1.0);
		COLOR = vec4(wsum > 0.0 ? sum / wsum : 0.5, mean_w, 0.0, 1.0);
	} else {
		vec2 grid = vec2(GRID_X, GRID_Y);
		vec2 cell = min(floor(UV * grid), grid - 1.0);
		vec2 cell_px = src / grid;
		int nx = int(clamp(ceil(cell_px.x), 1.0, 32.0));
		int ny = int(clamp(ceil(cell_px.y), 1.0, 32.0));
		vec2 stride = cell_px / vec2(float(nx), float(ny));
		vec2 origin = cell * cell_px;
		for (int j = 0; j < 32; j++) {
			if (j >= ny) {
				break;
			}
			for (int i = 0; i < 32; i++) {
				if (i >= nx) {
					break;
				}
				vec2 p = origin + (vec2(float(i), float(j)) + 0.5) * stride;
				vec2 uv = clamp((floor(p) + 0.5) / src, vec2(0.0), vec2(1.0));
				vec4 s = texture(TEXTURE, uv);
				sum += s.r * s.g;
				wsum += s.g;
				count += 1;
			}
		}
		COLOR = vec4(wsum > 0.0 ? sum / wsum : 0.5, wsum / max(float(count), 1.0), 0.0, 1.0);
	}
}
