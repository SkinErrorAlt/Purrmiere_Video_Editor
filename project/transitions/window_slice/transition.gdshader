shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int count : hint_range(2, 60) = 10;
uniform float smoothness : hint_range(0.0, 2.0) = 0.5;
uniform int direction = 0;

vec4 transition(vec2 uv) {
	float v = uv.x;
	float len = frame_px.x;
	if (direction == 1) {
		v = 1.0 - uv.x;
	} else if (direction == 2) {
		v = uv.y;
		len = frame_px.y;
	} else if (direction == 3) {
		v = 1.0 - uv.y;
		len = frame_px.y;
	}
	float n = float(max(count, 1));
	float s = max(smoothness, 0.0001);
	float pr = smoothstep(-s, 0.0, v - progress * (1.0 + s));
	float f = fract(v * n);
	float a = 1.0 / max(len / n, 1.0);
	float prx = pr * (1.0 + 2.0 * a) - a;
	float m = clamp((f - prx) / a, 0.0, 1.0);
	return mix(from_at(uv), to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}
