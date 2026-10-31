shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_nearest, repeat_disable;
uniform float skin_range : hint_range(10.0, 90.0) = 40.0;

const float GRID_X = 8.0;
const float GRID_Y = 4.0;
const int STEPS = 12;
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
const float SKIN_ANGLE = 2.1467;

vec2 chroma_of(vec3 rgb) {
	float y = dot(rgb, LUMA);
	return vec2((rgb.b - y) / 1.8556, (rgb.r - y) / 1.5748);
}

float wrap_angle(float x) {
	return x - 6.2831853 * floor((x + 3.1415927) / 6.2831853);
}

float skin_weight(vec3 rgb) {
	float y = dot(rgb, LUMA);
	vec2 cbcr = chroma_of(rgb);
	float m = length(cbcr);
	float d = abs(wrap_angle(atan(cbcr.y, cbcr.x) - SKIN_ANGLE));
	float half_w = radians(skin_range) * 0.5;
	float hue_w = 1.0 - smoothstep(half_w * 0.5, half_w + 0.0001, d);
	float sat_w = smoothstep(0.003, 0.009, m) * (1.0 - smoothstep(0.22, 0.32, m)) * smoothstep(0.07, 0.15, m / max(y, 0.01));
	float lum_w = smoothstep(0.02, 0.05, y) * (1.0 - smoothstep(0.93, 0.99, y));
	return hue_w * sat_w * lum_w;
}

vec3 to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec2 grid = vec2(GRID_X, GRID_Y);
	vec2 cell = min(floor(UV * grid), grid - 1.0);
	float ysum = 0.0;
	float wsum = 0.0;
	for (int j = 0; j < STEPS; j++) {
		for (int i = 0; i < STEPS; i++) {
			vec2 uv = (cell + (vec2(float(i), float(j)) + 0.5) / float(STEPS)) / grid;
			vec4 s = textureLod(effect_tex, uv, 0.0);
			if (s.a < 0.01) {
				continue;
			}
			vec3 rgb = clamp(s.rgb / s.a, 0.0, 1.0);
			float w = skin_weight(rgb) * s.a;
			ysum += dot(to_linear(rgb), LUMA) * w;
			wsum += w;
		}
	}
	float mean_y = wsum > 0.0001 ? ysum / wsum : 0.0;
	COLOR = vec4(sqrt(clamp(mean_y, 0.0, 1.0)), clamp(wsum / float(STEPS * STEPS), 0.0, 1.0), 0.0, 1.0);
}
