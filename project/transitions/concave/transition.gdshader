shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float angle : hint_range(10.0, 90.0) = 90.0;
uniform float lens : hint_range(10.0, 90.0) = 60.0;
uniform float eye : hint_range(-0.5, 0.5) = 0.1;
uniform float shading : hint_range(0.0, 1.0) = 0.0;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

const float BEND = -1.0;

mat3 rot_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, s), vec3(0.0, 1.0, 0.0), vec3(-s, 0.0, c));
}

float bezier_ease(float x) {
	vec2 p1 = vec2(0.26, 0.86);
	vec2 p2 = vec2(0.44, 0.985);
	float t = x;
	for (int i = 0; i < 6; i++) {
		float mt = 1.0 - t;
		float bx = 3.0 * mt * mt * t * p1.x + 3.0 * mt * t * t * p2.x + t * t * t;
		float dx = 3.0 * mt * mt * p1.x + 6.0 * mt * t * (p2.x - p1.x) + 3.0 * t * t * (1.0 - p2.x);
		t = clamp(t - (bx - x) / max(dx, 0.0001), 0.0, 1.0);
	}
	float mt = 1.0 - t;
	return 3.0 * mt * mt * t * p1.y + 3.0 * mt * t * t * p2.y + t * t * t;
}

vec4 slide(vec3 ro, vec3 rd, float t, float side, vec2 half_size, bool use_from, bool vertical, bool mirror, out float dist) {
	dist = -1.0;
	float shift = side * half_size.x * 2.0 * t;
	mat3 m = rot_y(BEND * side * radians(angle) * t);
	vec3 centre = m * vec3(shift, 0.0, 0.0) + vec3(shift, 0.0, 0.0);
	vec3 n = m * vec3(0.0, 0.0, -1.0);
	float dn = dot(rd, n);
	if (dn > -0.000001) {
		return vec4(0.0);
	}
	float th = dot(centre - ro, n) / dn;
	vec3 q = transpose(m) * (ro + rd * th - centre);
	if (th <= 0.0 || abs(q.x) > half_size.x || abs(q.y) > half_size.y) {
		return vec4(0.0);
	}
	dist = th;
	vec2 lw = q.xy;
	if (mirror) {
		lw.x = -lw.x;
	}
	if (vertical) {
		lw = vec2(lw.y, -lw.x);
	}
	vec2 cuv = tr_frame_uv(lw);
	vec4 c = use_from ? texture(from_tex, cuv) : texture(to_tex, cuv);
	return tr_shade(c, mix(1.0, abs(n.z), shading));
}

vec4 transition(vec2 uv) {
	float e = bezier_ease(clamp(progress, 0.0, 1.0));
	bool vertical = direction >= 2;
	bool mirror = direction == 1 || direction == 3;
	float d = tr_camera_distance(lens);
	vec2 w = tr_world(uv);
	vec3 ro = vec3(0.0, eye, -d);
	vec3 rd = normalize(vec3(w, 0.0) - ro);
	if (vertical) {
		ro = vec3(-ro.y, ro.x, ro.z);
		rd = vec3(-rd.y, rd.x, rd.z);
	}
	if (mirror) {
		ro.x = -ro.x;
		rd.x = -rd.x;
	}
	vec2 half_size = vertical ? vec2(0.5, tr_ratio() * 0.5) : vec2(tr_ratio() * 0.5, 0.5);
	float df;
	float dt;
	vec4 cf = slide(ro, rd, e, -1.0, half_size, true, vertical, mirror, df);
	vec4 ct = slide(ro, rd, 1.0 - e, 1.0, half_size, false, vertical, mirror, dt);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	vec4 res = bg;
	if (df > 0.0 && dt > 0.0) {
		res = df < dt ? tr_over(cf, tr_over(ct, bg)) : tr_over(ct, tr_over(cf, bg));
	} else if (df > 0.0) {
		res = tr_over(cf, bg);
	} else if (dt > 0.0) {
		res = tr_over(ct, bg);
	}
	res = mix(res, from_at(uv), 1.0 - smoothstep(0.0, 0.03, progress));
	return mix(res, to_at(uv), smoothstep(0.97, 1.0, progress));
}

void fragment() {
	COLOR = transition(UV);
}
