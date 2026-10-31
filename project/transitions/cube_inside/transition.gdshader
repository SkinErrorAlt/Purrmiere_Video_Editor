shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform int curve = 0;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.55;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

mat3 rot_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, s), vec3(0.0, 1.0, 0.0), vec3(-s, 0.0, c));
}

vec4 wall(vec3 ro, vec3 rd, float a, vec2 half_size, bool use_from, bool vertical, bool mirror, out float dist) {
	dist = -1.0;
	mat3 m = rot_y(a);
	vec3 pivot = vec3(0.0, 0.0, -half_size.x);
	vec3 centre = pivot + m * vec3(0.0, 0.0, half_size.x);
	vec3 n = m * vec3(0.0, 0.0, -1.0);
	float dn = dot(rd, n);
	if (dn > -0.000001) {
		return vec4(0.0);
	}
	float t = dot(centre - ro, n) / dn;
	vec3 q = transpose(m) * (ro + rd * t - centre);
	if (t <= 0.0 || abs(q.x) > half_size.x || abs(q.y) > half_size.y) {
		return vec4(0.0);
	}
	dist = t;
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
	float p = clamp(progress, 0.0, 1.0);
	float e = curve == 0 ? tr_ease(p, 4) : (curve == 1 ? tr_ease(p, 3) : p);
	bool vertical = direction >= 2;
	bool mirror = direction == 1 || direction == 3;
	float d = tr_camera_distance(lens);
	vec3 ro = vec3(0.0, 0.0, -d);
	vec3 rd = normalize(vec3(tr_world(uv), 0.0) - ro);
	if (vertical) {
		rd = vec3(-rd.y, rd.x, rd.z);
	}
	if (mirror) {
		rd.x = -rd.x;
	}
	vec2 half_size = vertical ? vec2(0.5, tr_ratio() * 0.5) : vec2(tr_ratio() * 0.5, 0.5);
	float df;
	float dt;
	vec4 cf = wall(ro, rd, TR_PI * 0.5 * e, half_size, true, vertical, mirror, df);
	vec4 ct = wall(ro, rd, -TR_PI * 0.5 * (1.0 - e), half_size, false, vertical, mirror, dt);
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
