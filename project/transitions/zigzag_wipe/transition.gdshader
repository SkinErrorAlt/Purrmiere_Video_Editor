shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform int teeth : hint_range(1, 40) = 8;
uniform float depth : hint_range(0.0, 0.5) = 0.08;
uniform float softness : hint_range(0.0, 0.2) = 0.0;
uniform int curve = 1;

float w_sweep(float v, float p, float soft) {
	float s = max(soft, 0.0001);
	float e = mix(-s, 1.0, p);
	return 1.0 - smoothstep(e, e + s, v);
}

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

float along_px() {
	return direction < 2 ? frame_px.x : frame_px.y;
}

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	float v = along_coord(uv);
	float t = across_coord(uv);
	float n = float(max(teeth, 1));
	float tri = abs(fract(t * n) - 0.5) * 2.0;
	float dp = max(depth, 0.0);
	float vv = (v + dp * tri) / (1.0 + dp);
	float px = 1.5 / (along_px() * (1.0 + dp));
	float m = w_sweep(vv, p, max(softness, px));
	return mix(from_at(uv), to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}
