shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform float rate : hint_range(4.0, 60.0) = 20.0;
uniform float slices : hint_range(4.0, 80.0) = 18.0;
uniform float colour_split : hint_range(0.0, 60.0) = 14.0;
uniform float blocks : hint_range(0.0, 1.0) = 0.3;
uniform float swap_width : hint_range(0.0, 0.5) = 0.2;

vec4 pick(bool use_to, vec2 uv) {
	return use_to ? to_clamped(uv) : from_clamped(uv);
}

vec4 transition(vec2 uv) {
	float p = progress;
	float env = pow(1.0 - abs(2.0 * p - 1.0), 0.6);
	float q = floor(p * rate);
	float bands = slices * (0.5 + tr_hash(vec2(q, 3.7)));
	float band = floor(uv.y * bands + tr_hash(vec2(q, 8.1)) * 3.0);
	float active = step(tr_hash(vec2(band, q + 0.5)), 0.25 + 0.6 * env);
	float shift = (tr_hash(vec2(band, q + 17.0)) - 0.5) * 2.0 * strength * 0.22 * env * active;
	vec2 bgrid = vec2(6.0, 4.0) * (1.0 + floor(tr_hash(vec2(q, 21.0)) * 3.0));
	vec2 bcell = floor(uv * bgrid);
	float bhit = step(tr_hash(bcell + vec2(q * 1.37, 5.0)), blocks * env * 0.35);
	vec2 boff = (tr_hash2(bcell + vec2(q, 9.0)) - 0.5) * vec2(0.14, 0.04) * env * bhit;
	vec2 src = uv + vec2(shift, 0.0) + boff;
	float split = colour_split * px_scale / max(frame_px.x, 1.0) * env * (0.4 + 0.6 * tr_hash(vec2(band, q + 31.0)));
	float lo = 0.5 - swap_width * 0.5;
	float hi = 0.5 + swap_width * 0.5;
	float sw = swap_width > 0.0 ? clamp((p - lo) / (hi - lo), 0.0, 1.0) : step(0.5, p);
	bool use_to = tr_hash(vec2(band * 1.7 + bcell.x, q + 41.0)) < sw;
	if (p >= hi) {
		use_to = true;
	}
	vec4 g = pick(use_to, src);
	vec4 r = pick(use_to, src + vec2(split, 0.0));
	vec4 b = pick(use_to, src - vec2(split, 0.0));
	vec4 col = vec4(r.r, g.g, b.b, max(g.a, max(r.a, b.a)));
	if (bhit > 0.5 && tr_hash(bcell + vec2(q, 77.0)) < 0.12) {
		col.rgb = col.a - col.rgb;
	}
	return col;
}

void fragment() {
	COLOR = transition(UV);
}
