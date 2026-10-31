shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform int direction = 0;
uniform int folds : hint_range(2, 20) = 8;
uniform float fold_depth : hint_range(0.0, 1.0) = 0.7;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
uniform float shadow : hint_range(0.0, 1.0) = 0.4;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec4 bg_fill() {
	float w = clamp(min(progress, 1.0 - progress) * 25.0, 0.0, 1.0);
	return vec4(background.rgb * background.a, background.a) * w;
}

float gather_u(float xs, float c, float q, float k) {
	float u = xs / c;
	for (int i = 0; i < 6; i++) {
		float g = c * (u + q * sin(k * u) / k) - xs;
		float dg = c * (1.0 + q * cos(k * u));
		u -= g / max(dg, 0.0001);
		u = clamp(u, 0.0, 1.0);
	}
	return u;
}

float pleat_light(float u, float q, float k) {
	float ph = k * u;
	return min(1.0, 1.0 - shading * q * (0.8 * (0.5 - 0.5 * cos(ph)) - 0.2 * sin(ph)));
}

vec4 transition(vec2 uv) {
	float e = tr_ease(progress, 3);
	float c = 1.0 - e;
	float xs = direction == 0 ? uv.x : 1.0 - uv.x;
	float k = 2.0 * TR_PI * float(folds);
	float q = fold_depth * 0.9 * sqrt(clamp(e * 1.5, 0.0, 1.0));
	float edge = c - xs;
	float cov = clamp(edge / max(fwidth(edge), 0.00001) + 0.5, 0.0, 1.0);
	vec4 top = vec4(0.0);
	if (c > 0.0001) {
		float u = gather_u(min(xs, c), c, q, k);
		vec2 m = vec2(direction == 0 ? u : 1.0 - u, uv.y);
		top = tr_shade(texture(from_tex, m), pleat_light(u, q, k)) * cov;
	}
	float sh = shadow * clamp(c * 10.0, 0.0, 1.0) * exp(-max(-edge, 0.0) / 0.05);
	vec4 under = tr_shade(to_at(uv), 1.0 - sh) * clamp(progress * 25.0, 0.0, 1.0);
	return tr_over(top, tr_over(under, bg_fill()));
}

void fragment() {
	COLOR = transition(UV);
}
