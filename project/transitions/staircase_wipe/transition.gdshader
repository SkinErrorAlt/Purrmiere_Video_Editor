shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction : hint_range(0, 3) = 0;
uniform int steps : hint_range(2, 40) = 10;
uniform float tread : hint_range(0.0, 1.0) = 0.4;
uniform bool flip = false;
uniform float softness : hint_range(0.0, 0.2) = 0.0;
uniform int curve = 1;

float along_coord(vec2 uv) {
	if (direction == 1) {
		return 1.0 - uv.x;
	} else if (direction == 2) {
		return uv.y;
	} else if (direction == 3) {
		return 1.0 - uv.y;
	}
	return uv.x;
}

float across_coord(vec2 uv) {
	return direction < 2 ? uv.y : uv.x;
}

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	float n = float(max(steps, 2));
	float across = across_coord(uv);
	if (flip) {
		across = 1.0 - across;
	}
	float stair = floor(across * n) / max(n - 1.0, 1.0);
	float dp = max(tread, 0.0);
	float v = (along_coord(uv) + dp * stair) / (1.0 + dp);
	float px = 1.5 / max(frame_px.x * (1.0 + dp), 1.0);
	float s = max(softness, px);
	float e = mix(-s, 1.0, p);
	float m = 1.0 - smoothstep(e, e + s, v);
	return mix(from_at(uv), to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}
