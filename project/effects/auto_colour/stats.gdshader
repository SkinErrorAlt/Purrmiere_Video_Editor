shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform int stage = 0;
uniform int stat = 0;
uniform int measure = 0;

const float GRID_X = 8.0;
const float GRID_Y = 4.0;

vec3 to_linear(vec3 v) {
	return mix(v / 12.92, pow((v + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), v));
}

vec4 fold(vec4 acc, vec4 s) {
	if (stat == 1) {
		return vec4(min(acc.rgb, s.rgb), 1.0);
	}
	if (stat == 2) {
		return vec4(max(acc.rgb, s.rgb), 1.0);
	}
	return acc + s;
}

vec4 start_value() {
	if (stat == 1) {
		return vec4(1.0, 1.0, 1.0, 1.0);
	}
	if (stat == 2) {
		return vec4(0.0, 0.0, 0.0, 1.0);
	}
	return vec4(0.0);
}

vec4 first_sample(vec2 uv) {
	vec4 s = texture(effect_tex, uv);
	if (stat == 0) {
		if (measure == 1 && s.a > 0.0001) {
			return vec4(to_linear(clamp(s.rgb / s.a, 0.0, 1.0)) * s.a, s.a);
		}
		return s;
	}
	if (s.a < 0.02) {
		return start_value();
	}
	return vec4(clamp(s.rgb / s.a, 0.0, 1.0), 1.0);
}

void fragment() {
	vec4 acc = start_value();
	float count = 0.0;
	if (stage == 0) {
		vec2 src = max(vec2(textureSize(effect_tex, 0)), vec2(1.0));
		vec2 foot = max(src * SCREEN_PIXEL_SIZE, vec2(1.0));
		int nx = int(clamp(ceil(foot.x), 1.0, 16.0));
		int ny = int(clamp(ceil(foot.y), 1.0, 16.0));
		vec2 stride = foot / vec2(float(nx), float(ny));
		vec2 origin = UV * src - foot * 0.5;
		for (int j = 0; j < 16; j++) {
			if (j >= ny) {
				break;
			}
			for (int i = 0; i < 16; i++) {
				if (i >= nx) {
					break;
				}
				vec2 p = origin + (vec2(float(i), float(j)) + 0.5) * stride;
				vec2 uv = stat == 0 ? p / src : (floor(p) + 0.5) / src;
				acc = fold(acc, first_sample(clamp(uv, vec2(0.0), vec2(1.0))));
				count += 1.0;
			}
		}
	} else {
		vec2 grid = vec2(GRID_X, GRID_Y);
		vec2 src = max(tex_size, vec2(1.0));
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
				vec2 uv = stat == 0 ? p / src : (floor(p) + 0.5) / src;
				acc = fold(acc, texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0))));
				count += 1.0;
			}
		}
	}
	if (stat == 0) {
		acc /= max(count, 1.0);
	}
	COLOR = acc;
}
