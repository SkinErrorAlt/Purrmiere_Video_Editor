shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float target : hint_range(0.05, 0.8) = 0.42;
uniform float strength : hint_range(0.0, 1.0) = 0.8;
uniform float max_boost : hint_range(0.0, 4.0) = 2.0;
uniform float max_cut : hint_range(0.0, 4.0) = 1.5;
uniform float protect_highlights : hint_range(0.0, 1.0) = 0.6;

const float GRID_X = 8.0;
const float GRID_Y = 4.0;
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float shoulder(float m, float knee) {
	if (m <= knee) {
		return m;
	}
	float r = 1.0 - knee;
	return knee + r * (1.0 - exp(-(m - knee) / r));
}

void fragment() {
	float sum = 0.0;
	float wsum = 0.0;
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 8; i++) {
			vec4 s = texture(TEXTURE, (vec2(float(i), float(j)) + 0.5) / vec2(GRID_X, GRID_Y));
			sum += s.r * s.g;
			wsum += s.g;
		}
	}
	float mean_log = wsum > 0.0001 ? (sum / wsum) * 12.0 - 12.0 : log2(0.18);
	float target_log = log2(pow(clamp(target, 0.05, 0.8), 2.2));
	float ev = clamp(target_log - mean_log, -clamp(max_cut, 0.0, 4.0), clamp(max_boost, 0.0, 4.0)) * clamp(strength, 0.0, 1.0);
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 lin = pow(rgb, vec3(2.2)) * exp2(ev);
	float m = max(lin.r, max(lin.g, lin.b));
	float knee = mix(1.0, 0.55, clamp(protect_highlights, 0.0, 1.0));
	if (m > knee && ev > 0.0) {
		lin *= shoulder(m, knee) / m;
	}
	vec3 outc = pow(clamp(lin, 0.0, 1.0), vec3(1.0 / 2.2));
	COLOR = vec4(outc * a, a);
}
