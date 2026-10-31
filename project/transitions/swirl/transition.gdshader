shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float turns : hint_range(0.25, 8.0) = 4.0;
uniform int direction = 0;
uniform float radius : hint_range(0.1, 1.5) = 1.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float blend : hint_range(0.05, 1.0) = 1.0;
uniform int curve = 0;

vec4 transition(vec2 uv) {
	float p = progress;
	float amount = 1.0 - abs(2.0 * p - 1.0);
	if (curve == 1) {
		amount = amount * amount * (3.0 - 2.0 * amount);
	}
	vec2 c = tr_world(centre);
	vec2 w = tr_world(uv) - c;
	float reach = max(radius * 0.5 * sqrt(tr_ratio() * tr_ratio() + 1.0), 0.001);
	float d = length(w);
	float f = clamp((reach - d) / reach, 0.0, 1.0);
	float spin = direction == 0 ? -1.0 : 1.0;
	float theta = f * f * amount * turns * 2.0 * TR_PI * spin;
	vec2 src = tr_frame_uv(tr_rotate(w, theta) + c);
	if (amount <= 0.0) {
		src = uv;
	}
	float m = clamp((p - 0.5) / blend + 0.5, 0.0, 1.0);
	m = m * m * (3.0 - 2.0 * m);
	return mix(from_clamped(src), to_clamped(src), m);
}

void fragment() {
	COLOR = transition(UV);
}
