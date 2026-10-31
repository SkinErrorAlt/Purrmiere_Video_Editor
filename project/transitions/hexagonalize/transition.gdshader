shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float size : hint_range(4.0, 240.0) = 96.0;
uniform int steps : hint_range(0, 60) = 0;
uniform float blend : hint_range(0.05, 1.0) = 0.35;
uniform int curve = 0;

vec2 hex_centre(vec2 q) {
	vec2 g = vec2(1.0, 1.7320508);
	vec2 a = (floor(q / g) + 0.5) * g;
	vec2 b = (floor((q - g * 0.5) / g) + 0.5) * g + g * 0.5;
	return dot(q - a, q - a) < dot(q - b, q - b) ? a : b;
}

vec4 transition(vec2 uv) {
	float p = progress;
	float t = 1.0 - abs(2.0 * p - 1.0);
	if (curve == 1) {
		t = t * t * (3.0 - 2.0 * t);
	}
	if (steps > 0) {
		t = ceil(t * float(steps)) / float(steps);
	}
	float s = size * px_scale * t;
	vec2 src = uv;
	if (s > 1.0) {
		vec2 c = frame_px * 0.5;
		vec2 q = (uv * frame_px - c) / s;
		src = (hex_centre(q) * s + c) / frame_px;
	}
	float m = clamp((p - 0.5) / blend + 0.5, 0.0, 1.0);
	return mix(from_clamped(src), to_clamped(src), m);
}

void fragment() {
	COLOR = transition(UV);
}
