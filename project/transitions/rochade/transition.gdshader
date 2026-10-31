shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float swing : hint_range(0.2, 1.5) = 0.7;
uniform float depth : hint_range(0.5, 6.0) = 2.4;
uniform float turn : hint_range(0.0, 80.0) = 35.0;
uniform float reflectivity : hint_range(0.0, 1.0) = 0.35;
uniform float falloff : hint_range(0.05, 1.0) = 0.4;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.5;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

mat3 rot_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, s), vec3(0.0, 1.0, 0.0), vec3(-s, 0.0, c));
}

vec4 card(vec3 ro, vec3 rd, vec3 centre, mat3 m, bool use_from, bool mirror, out float dist, out float height) {
	dist = -1.0;
	height = 0.0;
	vec3 n = m * vec3(0.0, 0.0, -1.0);
	float dn = dot(rd, n);
	if (dn > -0.000001) {
		return vec4(0.0);
	}
	float t = dot(centre - ro, n) / dn;
	vec3 q = transpose(m) * (ro + rd * t - centre);
	float hw = tr_ratio() * 0.5;
	if (t <= 0.0 || abs(q.x) > hw || abs(q.y) > 0.5) {
		return vec4(0.0);
	}
	dist = t;
	height = q.y + 0.5;
	vec2 lq = q.xy;
	if (mirror) {
		lq.x = -lq.x;
	}
	vec2 cuv = tr_frame_uv(lq);
	vec4 c = use_from ? texture(from_tex, cuv) : texture(to_tex, cuv);
	return tr_shade(c, mix(1.0, abs(n.z), shading));
}

vec4 scene(vec3 ro, vec3 rd, vec3 cf, mat3 mf, vec3 ct, mat3 mt, bool mirror, out float height) {
	float df;
	float dt;
	float hf;
	float ht;
	vec4 a = card(ro, rd, cf, mf, true, mirror, df, hf);
	vec4 b = card(ro, rd, ct, mt, false, mirror, dt, ht);
	height = 1.0;
	if (df > 0.0 && dt > 0.0) {
		height = df < dt ? hf : ht;
		return df < dt ? tr_over(a, b) : tr_over(b, a);
	} else if (df > 0.0) {
		height = hf;
		return a;
	} else if (dt > 0.0) {
		height = ht;
		return b;
	}
	return vec4(0.0);
}

vec4 transition(vec2 uv) {
	float e = tr_ease(progress, 3);
	float th = TR_PI * e;
	float side = swing * tr_ratio() * sin(th);
	float zc = depth * 0.5;
	vec3 cf = vec3(side, 0.0, zc - zc * cos(th));
	vec3 ct = vec3(-side, 0.0, zc + zc * cos(th));
	float tw = radians(turn) * sin(th);
	mat3 mf = rot_y(tw);
	mat3 mt = rot_y(-tw);
	float d = tr_camera_distance(lens);
	vec3 ro = vec3(0.0, 0.0, -d);
	vec2 w = tr_world(uv);
	bool mirror = direction == 1;
	if (mirror) {
		w.x = -w.x;
	}
	vec3 rd = normalize(vec3(w, 0.0) - ro);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	vec4 res = bg;
	if (rd.y < 0.0) {
		vec3 fp = ro + rd * ((-0.5 - ro.y) / rd.y);
		float rh;
		vec4 rc = scene(fp, vec3(rd.x, -rd.y, rd.z), cf, mf, ct, mt, mirror, rh);
		res = tr_over(rc * reflectivity * (1.0 - smoothstep(0.0, falloff, rh)), res);
	}
	float dh;
	res = tr_over(scene(ro, rd, cf, mf, ct, mt, mirror, dh), res);
	res = mix(res, from_at(uv), 1.0 - smoothstep(0.0, 0.03, progress));
	return mix(res, to_at(uv), smoothstep(0.97, 1.0, progress));
}

void fragment() {
	COLOR = transition(UV);
}
