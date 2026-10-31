shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float strength : hint_range(0.0, 0.5) = 0.1;
uniform float smoothing : hint_range(0.0, 60.0) = 10.0;
uniform int curve = 0;

vec4 soft_sample(bool use_from, vec2 uv, vec2 r) {
	vec4 s = vec4(0.0);
	s += use_from ? from_clamped(uv) : to_clamped(uv);
	s += use_from ? from_clamped(uv + vec2(r.x, 0.0)) : to_clamped(uv + vec2(r.x, 0.0));
	s += use_from ? from_clamped(uv - vec2(r.x, 0.0)) : to_clamped(uv - vec2(r.x, 0.0));
	s += use_from ? from_clamped(uv + vec2(0.0, r.y)) : to_clamped(uv + vec2(0.0, r.y));
	s += use_from ? from_clamped(uv - vec2(0.0, r.y)) : to_clamped(uv - vec2(0.0, r.y));
	return s * 0.2;
}

vec2 colour_pull(vec4 c) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	float hi = max(rgb.r, max(rgb.g, rgb.b));
	float lo = min(rgb.r, min(rgb.g, rgb.b));
	vec2 hue = vec2(rgb.r - 0.5 * (rgb.g + rgb.b), 0.8660254 * (rgb.g - rgb.b));
	float l = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	return hue * 1.2 + vec2(l - 0.5, 0.5 - l) * (1.0 - (hi - lo));
}

vec4 transition(vec2 uv) {
	float p = progress;
	vec2 r = smoothing * px_scale / frame_px;
	vec2 oa = colour_pull(soft_sample(true, uv, r));
	vec2 ob = colour_pull(soft_sample(false, uv, r));
	vec2 oc = (oa + ob) * 0.5 * strength * vec2(1.0 / tr_ratio(), 1.0);
	float m = curve == 1 ? tr_ease(p, 3) : p;
	vec4 a = from_clamped(uv + oc * p);
	vec4 b = to_clamped(uv - oc * (1.0 - p));
	return mix(a, b, m);
}

void fragment() {
	COLOR = transition(UV);
}
