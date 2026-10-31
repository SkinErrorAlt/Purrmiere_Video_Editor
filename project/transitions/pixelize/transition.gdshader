shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float block : hint_range(4.0, 240.0) = 72.0;
uniform int steps : hint_range(0, 60) = 0;
uniform float blend : hint_range(0.05, 1.0) = 0.35;
uniform int curve = 0;

vec4 transition(vec2 uv) {
	float p = progress;
	float t = 1.0 - abs(2.0 * p - 1.0);
	if (curve == 1) {
		t = t * t * (3.0 - 2.0 * t);
	}
	if (steps > 0) {
		t = ceil(t * float(steps)) / float(steps);
	}
	float s = block * px_scale * t;
	vec2 src = uv;
	if (s > 1.0) {
		vec2 c = frame_px * 0.5;
		vec2 px = uv * frame_px;
		px = (floor((px - c) / s) + 0.5) * s + c;
		src = px / frame_px;
	}
	float m = clamp((p - 0.5) / blend + 0.5, 0.0, 1.0);
	return mix(from_clamped(src), to_clamped(src), m);
}

void fragment() {
	COLOR = transition(UV);
}
