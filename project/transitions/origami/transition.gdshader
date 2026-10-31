shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform int back_face = 0;
uniform vec4 paper : source_color = vec4(0.95, 0.94, 0.9, 1.0);
uniform float pull_back : hint_range(0.0, 1.0) = 0.45;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

mat3 rot_x(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

mat3 rot_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, s), vec3(0.0, 1.0, 0.0), vec3(-s, 0.0, c));
}

mat3 rot_z(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
}

vec4 quad_hit(vec3 ro, vec3 rd, vec3 o, vec3 ex, vec3 ey) {
	vec3 n = cross(ex, ey);
	float dn = dot(rd, n);
	if (abs(dn) < 0.0000001) {
		return vec4(0.0, 0.0, 0.0, -1.0);
	}
	float t = dot(o - ro, n) / dn;
	vec3 q = ro + rd * t - o;
	vec2 st = vec2(dot(q, ex) / dot(ex, ex), dot(q, ey) / dot(ey, ey));
	if (t <= 0.0 || st.x < 0.0 || st.y < 0.0 || st.x > 1.0 || st.y > 1.0) {
		return vec4(st, 0.0, -1.0);
	}
	return vec4(st, dn < 0.0 ? 1.0 : -1.0, t);
}

vec4 settle(vec4 c, vec2 uv) {
	c = mix(c, from_at(uv), 1.0 - smoothstep(0.0, 0.03, progress));
	return mix(c, to_at(uv), smoothstep(0.97, 1.0, progress));
}

vec3 place(vec3 p, bool f1, bool f2, float a1, float a2, mat3 fly, vec3 pc, vec3 centre, vec3 shift) {
	if (f1) {
		p = rot_y(-a1) * p;
	}
	if (f2) {
		p = rot_x(-a2) * p;
	}
	p += centre;
	return pc + fly * (p - pc) + shift;
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float a1 = TR_PI * tr_ease(p / 0.36, 3);
	float a2 = TR_PI * tr_ease((p - 0.3) / 0.36, 3);
	float s3 = clamp((p - 0.6) / 0.4, 0.0, 1.0);
	float f = s3 * s3;
	float hw = tr_ratio() * 0.5;
	vec3 centre = vec3(hw * 0.5 * a1 / TR_PI, 0.25 * a2 / TR_PI, pull_back * 1.4 * tr_ease(p / 0.32, 3));
	vec3 pc = vec3(-hw * 0.5, -0.25, 0.0) + centre;
	mat3 fly = rot_z(f * 0.8) * rot_x(-f * 1.1) * rot_y(f * 0.6);
	vec3 shift = vec3(f * tr_ratio() * 1.3, f * 2.8, f * 2.2);
	float d = tr_camera_distance(lens);
	vec3 ro = vec3(0.0, 0.0, -d);
	vec2 w = tr_world(uv);
	bool flip = direction == 1;
	if (flip) {
		w.x = -w.x;
	}
	vec3 rd = normalize(vec3(w, 0.0) - ro);
	vec4 col[4];
	float key[4];
	for (int i = 0; i < 4; i++) {
		float fx = float(i % 2);
		float fy = float(i / 2);
		bool f1 = fx > 0.5;
		bool f2 = fy < 0.5;
		vec4 rect = vec4(fx * 0.5, fy * 0.5, 0.5, 0.5);
		vec3 o = vec3(-hw + fx * hw, 0.5 - fy * 0.5, 0.0);
		vec3 a = place(o, f1, f2, a1, a2, fly, pc, centre, shift);
		vec3 b = place(o + vec3(hw, 0.0, 0.0), f1, f2, a1, a2, fly, pc, centre, shift);
		vec3 c = place(o + vec3(0.0, -0.5, 0.0), f1, f2, a1, a2, fly, pc, centre, shift);
		vec3 ex = b - a;
		vec3 ey = c - a;
		vec4 h = quad_hit(ro, rd, a, ex, ey);
		float prio = a2 < TR_PI * 0.5 ? (f1 ? (f2 ? 3.0 : 2.0) : (f2 ? 1.0 : 0.0)) : (f2 ? (f1 ? 2.0 : 3.0) : (f1 ? 1.0 : 0.0));
		col[i] = vec4(0.0);
		key[i] = 1000000.0;
		if (h.w > 0.0) {
			vec2 cuv = rect.xy + h.xy * rect.zw;
			if (flip) {
				cuv.x = 1.0 - cuv.x;
			}
			vec4 pic = texture(from_tex, cuv);
			float light = mix(1.0, abs(normalize(cross(ex, ey)).z), shading);
			if (h.z < 0.0 && back_face == 1) {
				pic = vec4(paper.rgb * paper.a, paper.a) * pic.a;
				light *= 0.9;
			}
			col[i] = tr_shade(pic, light);
			key[i] = h.w - prio * 0.004;
		}
	}
	for (int i = 0; i < 3; i++) {
		for (int j = 0; j < 3 - i; j++) {
			if (key[j] < key[j + 1]) {
				float tk = key[j];
				key[j] = key[j + 1];
				key[j + 1] = tk;
				vec4 tc = col[j];
				col[j] = col[j + 1];
				col[j + 1] = tc;
			}
		}
	}
	vec4 bg = vec4(background.rgb * background.a, background.a);
	vec4 res = tr_over(to_at(uv), bg);
	for (int i = 0; i < 4; i++) {
		res = tr_over(col[i], res);
	}
	return settle(res, uv);
}

void fragment() {
	COLOR = transition(UV);
}
