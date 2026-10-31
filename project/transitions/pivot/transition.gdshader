shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int corner = 0;
uniform int mode = 0;
uniform float swing : hint_range(90.0, 180.0) = 90.0;
uniform float shadow : hint_range(0.0, 1.0) = 0.5;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

float box_sd(vec2 p, vec2 half_size) {
	vec2 q = abs(p) - half_size;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
}

vec4 transition(vec2 uv) {
	float e = tr_ease(progress, 3);
	bool mx = corner == 1 || corner == 3;
	bool my = corner >= 2;
	vec2 w = tr_world(uv);
	if (mx) {
		w.x = -w.x;
	}
	if (my) {
		w.y = -w.y;
	}
	vec2 half_size = vec2(tr_ratio() * 0.5, 0.5);
	vec2 pivot = vec2(-half_size.x, half_size.y);
	float theta = radians(swing) * (mode == 0 ? e : 1.0 - e);
	vec2 local = tr_rotate(w - pivot, theta) + pivot;
	vec2 luv = tr_frame_uv(local);
	if (mx) {
		luv.x = 1.0 - luv.x;
	}
	if (my) {
		luv.y = 1.0 - luv.y;
	}
	vec4 top = mode == 0 ? from_at(luv) : to_at(luv);
	vec4 under = mode == 0 ? to_at(uv) : from_at(uv);
	vec2 off = vec2(0.025, -0.035);
	vec2 sl = tr_rotate(w - off - pivot, theta) + pivot;
	float sd = box_sd(sl, half_size);
	float amt = shadow * 0.6 * sin(TR_PI * e) * (1.0 - smoothstep(-0.02, 0.06, sd));
	under = tr_shade(under, 1.0 - amt);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	bg = vec4(bg.rgb * (1.0 - amt), bg.a);
	vec4 res = tr_over(top, tr_over(under, bg));
	res = mix(res, from_at(uv), 1.0 - smoothstep(0.0, 0.03, progress));
	return mix(res, to_at(uv), smoothstep(0.97, 1.0, progress));
}

void fragment() {
	COLOR = transition(UV);
}
