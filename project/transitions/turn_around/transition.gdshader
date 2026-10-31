shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float depth : hint_range(0.0, 3.0) = 1.5;
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

vec4 card(vec3 ro, vec3 rd, vec3 centre, mat3 m, bool mirror, out float dist, out float height) {
	dist = -1.0;
	height = 0.0;
	vec3 n = m * vec3(0.0, 0.0, -1.0);
	float dn = dot(rd, n);
	if (abs(dn) < 0.000001) {
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
	bool front = dn < 0.0;
	vec2 lq = vec2(front ? q.x : -q.x, q.y);
	if (mirror) {
		lq.x = -lq.x;
	}
	vec2 cuv = tr_frame_uv(lq);
	vec4 c = front ? texture(from_tex, cuv) : texture(to_tex, cuv);
	return tr_shade(c, mix(1.0, abs(n.z), shading));
}

vec4 transition(vec2 uv) {
	float e = tr_ease(progress, 3);
	float back = depth * sin(TR_PI * e);
	mat3 m = rot_y(-TR_PI * e);
	vec3 centre = vec3(0.0, 0.0, back);
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
		float rdist;
		float rh;
		vec4 rc = card(fp, vec3(rd.x, -rd.y, rd.z), centre, m, mirror, rdist, rh);
		res = tr_over(rc * reflectivity * (1.0 - smoothstep(0.0, falloff, rh)), res);
	}
	float dd;
	float dh;
	res = tr_over(card(ro, rd, centre, m, mirror, dd, dh), res);
	res = mix(res, from_at(uv), 1.0 - smoothstep(0.0, 0.03, progress));
	return mix(res, to_at(uv), smoothstep(0.97, 1.0, progress));
}

void fragment() {
	COLOR = transition(UV);
}
