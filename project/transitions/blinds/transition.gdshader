shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int orientation = 0;
uniform int slats : hint_range(2, 40) = 8;
uniform int style = 0;
uniform float stagger : hint_range(0.0, 0.9) = 0.2;
uniform float shading : hint_range(0.0, 1.0) = 0.5;
uniform int curve = 1;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

float w_sweep(float v, float p, float soft) {
	float s = max(soft, 0.0001);
	float e = mix(-s, 1.0, p);
	return 1.0 - smoothstep(e, e + s, v);
}

vec4 transition(vec2 uv) {
	float n = float(max(slats, 1));
	float c = orientation == 0 ? uv.y : uv.x;
	float len = orientation == 0 ? frame_px.y : frame_px.x;
	float idx = min(floor(c * n), n - 1.0);
	float t = c * n - idx;
	float k = n > 1.0 ? idx / (n - 1.0) : 0.0;
	float st = clamp(stagger, 0.0, 0.9);
	float q = clamp((progress - st * k) / (1.0 - st), 0.0, 1.0);
	q = tr_ease(q, curve == 1 ? 3 : 0);
	float slat_px = max(len / n, 1.0);
	if (style == 1) {
		float m = w_sweep(t, q, 1.0 / slat_px);
		return mix(from_at(uv), to_at(uv), m);
	}
	float cs = cos(q * TR_PI);
	float half_h = abs(cs) * (0.5 + 1.0 / slat_px);
	float d = t - 0.5;
	float cov = clamp((half_h - abs(d)) * slat_px + 0.5, 0.0, 1.0);
	float local = clamp(0.5 + d / max(abs(cs), 0.0001), 0.0, 1.0);
	float src = (idx + local) / n;
	vec2 suv = orientation == 0 ? vec2(uv.x, src) : vec2(src, uv.y);
	vec4 pic = q < 0.5 ? from_at(suv) : to_at(suv);
	float tilt = q < 0.5 ? (0.5 - local) : (local - 0.5);
	float light = mix(1.0, (0.35 + 0.65 * abs(cs)) * (1.0 + 0.25 * (1.0 - abs(cs)) * tilt), shading);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	return tr_shade(pic, light) * cov + bg * (1.0 - cov);
}

void fragment() {
	COLOR = transition(UV);
}
