shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform int stage = 1;
uniform int measure : hint_range(0, 1) = 0;
uniform bool keep_alpha = true;

const float GRID_X = 8.0;
const float GRID_Y = 4.0;

vec3 to_srgb(vec3 v) {
	return mix(v * 12.92, 1.055 * pow(max(v, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), v));
}

void fragment() {
	if (stage == 0) {
		vec4 total = vec4(0.0);
		for (int j = 0; j < 4; j++) {
			for (int i = 0; i < 8; i++) {
				total += texture(TEXTURE, (vec2(float(i), float(j)) + 0.5) / vec2(GRID_X, GRID_Y));
			}
		}
		vec3 mean = total.a > 0.0001 ? clamp(total.rgb / total.a, 0.0, 1.0) : vec3(0.0);
		if (measure == 1) {
			mean = to_srgb(mean);
		}
		COLOR = vec4(clamp(mean, 0.0, 1.0), total.a > 0.0001 ? 1.0 : 0.0);
	} else {
		vec4 m = texture(TEXTURE, vec2(0.5, 0.5));
		float a = texture(effect_tex, UV).a;
		if (keep_alpha) {
			COLOR = vec4(m.rgb * a, a);
		} else {
			COLOR = vec4(m.rgb * m.a, m.a);
		}
	}
}
