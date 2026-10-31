shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float radius : hint_range(0.03, 0.5) = 0.16;
uniform float tilt : hint_range(-30.0, 30.0) = 6.0;
uniform int back_face = 0;
uniform vec4 paper : source_color = vec4(0.96, 0.95, 0.92, 1.0);
uniform float shadow : hint_range(0.0, 1.0) = 0.5;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec4 page(vec2 s, bool back, float tilt_r, bool mirror) {
	vec2 wp = tr_rotate(s, tilt_r);
	if (mirror) {
		wp.x = -wp.x;
	}
	vec2 puv = tr_frame_uv(wp);
	if (!tr_inside(puv)) {
		return vec4(0.0);
	}
	vec4 c = texture(from_tex, puv);
	if (back && back_face == 1) {
		c = vec4(paper.rgb * paper.a, paper.a) * c.a;
	}
	return c;
}

vec4 transition(vec2 uv) {
	float e = tr_ease(progress, 3);
	bool mirror = direction == 1;
	vec2 w = tr_world(uv);
	if (mirror) {
		w.x = -w.x;
	}
	float tilt_r = radians(tilt);
	vec2 r = tr_rotate(w, -tilt_r);
	float hw = tr_ratio() * 0.5;
	float big_x = hw * cos(abs(tilt_r)) + 0.5 * sin(abs(tilt_r));
	float rad = radius;
	float xc = mix(big_x, -big_x - 1.6 * rad, e);
	float x = r.x;
	vec4 under = to_at(uv);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	vec4 res;
	if (x <= xc) {
		vec4 flat_c = page(vec2(x, r.y), false, tilt_r, mirror);
		vec4 back_c = page(vec2(2.0 * xc + TR_PI * rad - x, r.y), true, tilt_r, mirror);
		back_c = tr_shade(back_c, mix(1.0, 0.86, shading));
		float near_fold = 1.0 - smoothstep(0.0, rad * 1.2, xc - x);
		flat_c = tr_shade(flat_c, 1.0 - 0.35 * shadow * near_fold * step(0.001, back_c.a));
		res = tr_over(back_c, tr_over(flat_c, tr_over(under, bg)));
	} else {
		float k = (x - xc) / rad;
		float sh = shadow * 0.6 * exp(-max(x - xc - rad, 0.0) / (rad * 1.5)) * smoothstep(0.0, 0.05, e) * (1.0 - smoothstep(0.95, 1.0, e));
		vec4 base = tr_shade(under, 1.0 - sh);
		res = tr_over(base, bg);
		if (k <= 1.0) {
			float pl = asin(clamp(k, 0.0, 1.0));
			float pu = TR_PI - pl;
			vec4 lower = page(vec2(xc + rad * pl, r.y), false, tilt_r, mirror);
			vec4 upper = page(vec2(xc + rad * pu, r.y), true, tilt_r, mirror);
			lower = tr_shade(lower, mix(1.0, 0.45 + 0.55 * cos(pl), shading));
			upper = tr_shade(upper, mix(1.0, 0.8 + 0.25 * sin(pl) * (1.0 - k) + 0.1 * (1.0 - k), shading));
			res = tr_over(upper, tr_over(lower, res));
		}
	}
	res = mix(res, from_at(uv), 1.0 - smoothstep(0.0, 0.03, progress));
	return mix(res, to_at(uv), smoothstep(0.97, 1.0, progress));
}

void fragment() {
	COLOR = transition(UV);
}
