shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float waves : hint_range(0.5, 10.0) = 2.0;
uniform float amplitude : hint_range(0.0, 0.4) = 0.08;
uniform float travel : hint_range(0.0, 6.0) = 1.0;
uniform int travel_direction = 0;
uniform bool constant_speed = false;
uniform float speed : hint_range(0.0, 6.0) = 1.0;
uniform float softness : hint_range(0.0, 0.2) = 0.01;
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
	float amp = max(amplitude, 0.0);
	float phase = constant_speed ? progress * max(duration, 0.0) * speed : progress * travel;
	if (travel_direction == 1) {
		phase = -phase;
	}
	float wv = 0.5 + 0.5 * sin(2.0 * TR_PI * (t * waves - phase));
	float vv = (v + amp * wv) / (1.0 + amp);
	float px = 1.5 / (along_px() * (1.0 + amp));
	float m = w_sweep(vv, p, max(softness, px));
	return mix(from_at(uv), to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}
