shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float block_px : hint_range(6.0, 64.0) = 18.0;
uniform float smear : hint_range(0.0, 1.0) = 0.7;
uniform float mush : hint_range(0.0, 1.0) = 0.5;
uniform float snap_point : hint_range(0.6, 0.98) = 0.84;

float luma(vec4 c) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : c.rgb;
	return dot(rgb, vec3(0.299, 0.587, 0.114));
}

vec4 transition(vec2 uv) {
	float e = progress;
	if (e >= snap_point) {
		return to_at(uv);
	}
	float t = e / max(snap_point, 0.001);
	vec2 bpx = vec2(max(block_px, 2.0)) / max(frame_px, vec2(1.0));
	vec2 block = (floor(uv / bpx) + 0.5) * bpx;

	float lR = luma(to_clamped(block + vec2(bpx.x, 0.0)));
	float lL = luma(to_clamped(block - vec2(bpx.x, 0.0)));
	float lD = luma(to_clamped(block + vec2(0.0, bpx.y)));
	float lU = luma(to_clamped(block - vec2(0.0, bpx.y)));
	vec2 mv = vec2(lR - lL, lD - lU) * 2.0 + (tr_hash2(block) - 0.5) * 0.5;

	vec2 suv = clamp(uv - mv * smear * t * 0.35, vec2(0.0), vec2(1.0));
	vec4 base = from_clamped(suv);

	float mp = tr_hash(block + vec2(3.1, 1.7));
	if (mp < t * mush) {
		base = from_clamped(block);
	}
	float rp = tr_hash(block + vec2(7.7, 5.3));
	if (rp < t) {
		base = mix(base, to_clamped(block), smoothstep(rp, rp + 0.25, t));
	}
	return base;
}

void fragment() {
	COLOR = transition(UV);
}
