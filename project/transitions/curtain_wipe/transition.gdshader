shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int style = 0;
uniform int folds : hint_range(2, 24) = 7;
uniform float fold_depth : hint_range(0.0, 1.0) = 0.5;
uniform float drape : hint_range(0.0, 1.0) = 0.35;
uniform float shadow : hint_range(0.0, 1.0) = 0.5;
uniform int curve = 1;

vec4 transition(vec2 uv) {
	float e = tr_ease(progress, curve == 1 ? 3 : 0);
	bool right = uv.x >= 0.5;
	float hx;
	float across;
	float span_px;
	float bell;
	if (style == 1) {
		hx = uv.y;
		across = uv.x;
		span_px = frame_px.y;
		bell = 0.5 - 0.5 * cos(2.0 * TR_PI * across * 3.0);
	} else {
		hx = right ? (1.0 - uv.x) * 2.0 : uv.x * 2.0;
		across = uv.y;
		span_px = frame_px.x * 0.5;
		bell = exp(-pow((across - 0.62) / 0.22, 2.0));
	}
	float dr = clamp(drape, 0.0, 1.0);
	float wr = (1.0 - e) * (1.0 - dr * sin(TR_PI * e) * (style == 1 ? 0.25 : 0.6) * bell);
	float wr_px = wr * (1.0 + 1.0 / span_px);
	float cov = clamp((wr_px - hx) * span_px + 0.5, 0.0, 1.0);
	float s = clamp(hx / max(wr, 0.00001), 0.0, 1.0);
	float nf = float(max(folds, 1));
	float fd = clamp(fold_depth, 0.0, 1.0);
	float amt = fd * e * 0.8;
	float s2 = s + amt * sin(2.0 * TR_PI * nf * s) / (2.0 * TR_PI * nf);
	vec2 src;
	if (style == 1) {
		src = vec2(uv.x, s2);
	} else {
		src = vec2(right ? 1.0 - s2 * 0.5 : s2 * 0.5, uv.y);
	}
	float light = 1.0 - fd * e * 0.6 * (0.5 - 0.5 * cos(2.0 * TR_PI * nf * s));
	vec4 cur = tr_shade(from_at(src), light);
	float gap = max(hx - wr, 0.0) * span_px;
	float sh = clamp(shadow, 0.0, 1.0) * 0.6 * (1.0 - e) * exp(-gap / (40.0 * max(px_scale, 0.01)));
	vec4 inc = tr_shade(to_at(uv), 1.0 - sh);
	return cur * cov + inc * (1.0 - cov);
}

void fragment() {
	COLOR = transition(UV);
}
