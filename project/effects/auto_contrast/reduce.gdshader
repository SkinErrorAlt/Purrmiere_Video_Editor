shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_nearest, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform bool use_max = false;
uniform bool from_effect = true;

const float GRID_X = 8.0;
const float GRID_Y = 4.0;

vec3 pick(vec3 acc, vec3 v) {
	return use_max ? max(acc, v) : min(acc, v);
}

void fragment() {
	vec3 acc = use_max ? vec3(0.0) : vec3(1.0);
	if (from_effect) {
		vec2 src = max(vec2(textureSize(effect_tex, 0)), vec2(1.0));
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
				vec4 s = texture(effect_tex, uv);
				if (s.a > 0.0001) {
					acc = pick(acc, clamp(s.rgb / s.a, 0.0, 1.0));
				}
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
				vec2 uv = clamp((floor(p) + 0.5) / src, vec2(0.0), vec2(1.0));
				acc = pick(acc, texture(TEXTURE, uv).rgb);
			}
		}
	}
	COLOR = vec4(acc, 1.0);
}
