shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float bounce : hint_range(0.0, 1.0) = 1.0;
uniform float squash : hint_range(0.0, 1.0) = 0.3;
uniform float shadow : hint_range(0.0, 1.0) = 0.5;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec2 to_canon(vec2 uv) {
	if (direction == 1) {
		return vec2(uv.x, 1.0 - uv.y);
	} else if (direction == 2) {
		return vec2(uv.y, uv.x);
	} else if (direction == 3) {
		return vec2(uv.y, 1.0 - uv.x);
	}
	return uv;
}

vec2 from_canon(vec2 c) {
	if (direction == 1) {
		return vec2(c.x, 1.0 - c.y);
	} else if (direction == 2) {
		return vec2(c.y, c.x);
	} else if (direction == 3) {
		return vec2(1.0 - c.y, c.x);
	}
	return c;
}

vec4 transition(vec2 uv) {
	float t = clamp(progress, 0.0, 1.0);
	float smooth_fall = 1.0 - pow(1.0 - t, 3.0);
	float fall = mix(smooth_fall, tr_ease(t, 7), bounce);
	float off = 1.0 - fall;
	float impact = 0.0;
	if (t > 0.3636) {
		float k = (t - 0.3636) / 0.6364;
		impact = exp(-7.0 * k) * sin(TR_PI * min(k * 6.0, 1.0)) * bounce;
	}
	float sq = squash * 0.04 * impact;
	vec2 c = to_canon(uv);
	vec2 cc = c;
	cc.y = cc.y + off;
	cc.y = 1.0 - (1.0 - cc.y) * (1.0 + sq);
	vec4 top = to_at(from_canon(cc));
	vec4 under = from_at(uv);
	float edge = 1.0 - off;
	float below = c.y - edge;
	float amt = shadow * smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.0, 0.07 + 0.1 * off, below)) * step(0.0, below);
	under = tr_shade(under, 1.0 - 0.6 * amt);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	vec4 res = tr_over(top, tr_over(under, bg));
	res = mix(res, from_at(uv), 1.0 - smoothstep(0.0, 0.03, progress));
	return mix(res, to_at(uv), smoothstep(0.97, 1.0, progress));
}

void fragment() {
	COLOR = transition(UV);
}
