shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int segments : hint_range(2, 16) = 6;
uniform float spin : hint_range(-2.0, 2.0) = 0.5;
uniform float zoom : hint_range(0.25, 4.0) = 1.4;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float blend : hint_range(0.05, 1.0) = 0.3;
uniform float hold : hint_range(0.0, 0.8) = 0.2;

vec2 fold(vec2 v, float n) {
	float seg = 2.0 * TR_PI / n;
	float a = atan(v.y, v.x);
	a = mod(a, seg);
	a = seg * 0.5 - abs(a - seg * 0.5);
	return vec2(cos(a), sin(a)) * length(v);
}

vec4 transition(vec2 uv) {
	float p = progress;
	float ramp = max((1.0 - hold) * 0.5, 0.01);
	float w = smoothstep(0.0, ramp, p) * (1.0 - smoothstep(1.0 - ramp, 1.0, p));
	float sw = clamp((p - 0.5) / blend + 0.5, 0.0, 1.0);
	sw = sw * sw * (3.0 - 2.0 * sw);
	vec4 plain = mix(from_at(uv), to_at(uv), sw);
	if (w <= 0.0) {
		return plain;
	}
	vec2 c = tr_world(centre);
	vec2 v = tr_world(uv) - c;
	float turn = spin * 2.0 * TR_PI * (p - 0.5);
	v = tr_rotate(v, turn);
	v /= mix(1.0, zoom, w);
	v = fold(v, float(max(segments, 2)));
	v = tr_rotate(v, -turn * 1.5 + 0.35);
	vec2 src = tr_frame_uv(v + c);
	vec4 kal = mix(from_mirrored(src), to_mirrored(src), sw);
	return mix(plain, kal, w);
}

void fragment() {
	COLOR = transition(UV);
}
