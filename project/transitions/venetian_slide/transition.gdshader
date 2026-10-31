shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform int strips : hint_range(2, 200) = 24;
uniform float softness : hint_range(0.0, 0.5) = 0.04;
uniform int curve = 0;

float w_sweep(float v, float p, float soft) {
	float s = max(soft, 0.0001);
	float e = mix(-s, 1.0, p);
	return 1.0 - smoothstep(e, e + s, v);
}

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	bool leftward = direction < 2;
	bool down = direction == 0 || direction == 2;
	float x = leftward ? 1.0 - uv.x : uv.x;
	float y = down ? uv.y : 1.0 - uv.y;
	float n = float(max(strips, 1));
	float col = min(floor(x * n), n - 1.0);
	float k = n > 1.0 ? col / (n - 1.0) : 0.0;
	float o = (k + y) * 0.5;
	float m = w_sweep(o, p, max(softness, 0.5 / frame_px.y));
	return mix(from_at(uv), to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}
