shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int timing = 1;
uniform int reveal_mode = 1;
uniform float warp : hint_range(0.0, 0.3) = 0.09;
uniform float smoothness : hint_range(0.01, 0.5) = 0.16;
uniform float bias : hint_range(-0.5, 0.5) = 0.0;

int curve_of(int t) {
	if (t == 1) { return 3; }
	else if (t == 2) { return 4; }
	else if (t == 3) { return 2; }
	else if (t == 4) { return 5; }
	else if (t == 5) { return 7; }
	return 0;
}

float luma(vec4 c) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : c.rgb;
	return dot(rgb, vec3(0.299, 0.587, 0.114));
}

vec4 transition(vec2 uv) {
	float e = tr_ease(progress, curve_of(timing));
	vec2 px = 1.0 / max(frame_px, vec2(1.0));
	float warp_amt = warp * sin(e * TR_PI);

	float dR = luma(to_clamped(uv + vec2(px.x, 0.0))) - luma(from_clamped(uv + vec2(px.x, 0.0)));
	float dL = luma(to_clamped(uv - vec2(px.x, 0.0))) - luma(from_clamped(uv - vec2(px.x, 0.0)));
	float dU = luma(to_clamped(uv - vec2(0.0, px.y))) - luma(from_clamped(uv - vec2(0.0, px.y)));
	float dD = luma(to_clamped(uv + vec2(0.0, px.y))) - luma(from_clamped(uv + vec2(0.0, px.y)));
	vec2 grad = vec2(dR - dL, dD - dU);
	vec2 wuv = clamp(uv + grad * warp_amt, vec2(0.0), vec2(1.0));

	vec4 a = from_clamped(wuv);
	vec4 b = to_clamped(wuv);

	float f;
	if (reveal_mode == 0) {
		f = luma(from_clamped(uv));
	} else if (reveal_mode == 1) {
		f = clamp(0.5 + 0.5 * (luma(to_clamped(uv)) - luma(from_clamped(uv))), 0.0, 1.0);
	} else {
		float lc = luma(from_clamped(uv));
		float le = abs(luma(from_clamped(uv + vec2(px.x, 0.0))) - lc) + abs(luma(from_clamped(uv + vec2(0.0, px.y))) - lc);
		f = clamp(le * 4.0, 0.0, 1.0);
	}

	float thr = mix(1.0 + smoothness, -smoothness, e) + bias;
	float m = smoothstep(thr - smoothness, thr + smoothness, f);
	return mix(a, b, m);
}

void fragment() {
	COLOR = transition(UV);
}
