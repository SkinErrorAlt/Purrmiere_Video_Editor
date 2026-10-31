shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D min_tex : filter_nearest, repeat_disable;
uniform int mode : hint_range(0, 1) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float black_bias : hint_range(0.0, 0.4) = 0.0;
uniform float white_bias : hint_range(0.0, 0.4) = 0.0;

const float GRID_X = 8.0;
const float GRID_Y = 4.0;

void fragment() {
	vec3 lo = vec3(1.0);
	vec3 hi = vec3(0.0);
	vec2 grid = vec2(GRID_X, GRID_Y);
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 8; i++) {
			vec2 uv = (vec2(float(i), float(j)) + 0.5) / grid;
			lo = min(lo, texture(min_tex, uv).rgb);
			hi = max(hi, texture(TEXTURE, uv).rgb);
		}
	}
	if (mode == 0) {
		lo = vec3(min(lo.r, min(lo.g, lo.b)));
		hi = vec3(max(hi.r, max(hi.g, hi.b)));
	}
	vec3 found = step(lo, hi);
	vec3 span = max(hi - lo, vec3(0.1));
	vec3 base = (lo + hi) * 0.5 - span * 0.5;
	base = mix(vec3(0.0), base, found);
	span = mix(vec3(1.0), span, found);
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 stretched = clamp((rgb - base) / span, 0.0, 1.0);
	stretched = black_bias + stretched * (1.0 - black_bias - white_bias);
	rgb = mix(rgb, stretched, strength);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
