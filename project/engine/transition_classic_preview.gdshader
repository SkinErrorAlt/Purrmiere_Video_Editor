shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int kind = 1;

const float SOFT = 0.045;

vec4 transition(vec2 uv) {
	vec4 a = from_at(uv);
	if (kind == 1) {
		return mix(a, to_at(uv), progress);
	}
	if (kind == 2 || kind == 3) {
		vec4 dip = kind == 2 ? vec4(0.0, 0.0, 0.0, 1.0) : vec4(1.0);
		float da = clamp(progress * 2.0, 0.0, 1.0);
		float ia = progress < 0.5 ? 0.0 : (progress - 0.5) * 2.0;
		return tr_over(to_at(uv) * ia, tr_over(dip * da, a));
	}
	if (kind >= 4 && kind <= 7) {
		float x = uv.x;
		if (kind == 4) {
			x = 1.0 - uv.x;
		} else if (kind == 6) {
			x = 1.0 - uv.y;
		} else if (kind == 7) {
			x = uv.y;
		}
		float edge = progress * (1.0 + SOFT * 2.0) - SOFT;
		float wa = 1.0 - smoothstep(edge - SOFT, edge + SOFT, x);
		return tr_over(to_at(uv) * wa, a);
	}
	vec2 dir = vec2(0.0, -1.0);
	if (kind == 8 || kind == 12) {
		dir = vec2(1.0, 0.0);
	} else if (kind == 9 || kind == 13) {
		dir = vec2(-1.0, 0.0);
	} else if (kind == 10 || kind == 14) {
		dir = vec2(0.0, 1.0);
	}
	vec2 in_off = dir * (1.0 - progress);
	vec2 out_off = kind <= 11 ? -dir * progress : vec2(0.0);
	return tr_over(to_at(uv - in_off), from_at(uv - out_off));
}

void fragment() {
	COLOR = transition(UV);
}
