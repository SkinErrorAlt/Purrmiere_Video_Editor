shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float turn : hint_range(0.0, 80.0) = 45.0;
uniform float spread : hint_range(0.2, 1.2) = 0.55;
uniform float depth : hint_range(0.2, 3.0) = 1.8;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.5;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

mat3 rot_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, s), vec3(0.0, 1.0, 0.0), vec3(-s, 0.0, c));
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

vec4 card(vec3 ro, vec3 rd, vec3 centre, mat3 m, bool use_from, bool mirror, out float dist) {
	float hw = tr_ratio() * 0.5;
	vec3 o = centre + m * vec3(-hw, 0.5, 0.0);
	vec3 ex = m * vec3(hw * 2.0, 0.0, 0.0);
	vec3 ey = m * vec3(0.0, -1.0, 0.0);
	vec4 h = quad_hit(ro, rd, o, ex, ey);
	dist = h.w;
	if (h.w < 0.0) {
		return vec4(0.0);
	}
	vec2 cuv = h.xy;
	if (mirror) {
		cuv.x = 1.0 - cuv.x;
	}
	vec4 c = use_from ? texture(from_tex, cuv) : texture(to_tex, cuv);
	float light = mix(1.0, abs(normalize(cross(ex, ey)).z), shading);
	return tr_shade(c, light);
}

vec4 transition(vec2 uv) {
	float e = tr_ease(progress, 4);
	float s = sin(TR_PI * e);
	float back = (1.0 - cos(TR_PI * e)) * 0.5;
	float side = s * spread * tr_ratio();
	float a = radians(turn) * s;
	float d = tr_camera_distance(lens);
	vec3 ro = vec3(0.0, 0.0, -d);
	vec2 w = tr_world(uv);
	bool mirror = direction == 1;
	if (mirror) {
		w.x = -w.x;
	}
	vec3 rd = normalize(vec3(w, 0.0) - ro);
	float df;
	float dt;
	vec4 cf = card(ro, rd, vec3(-side, 0.0, back * depth), rot_y(-a), true, mirror, df);
	vec4 ct = card(ro, rd, vec3(side, 0.0, (1.0 - back) * depth), rot_y(a), false, mirror, dt);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	vec4 res = bg;
	if (df >= 0.0 && dt >= 0.0) {
		res = df < dt ? tr_over(cf, tr_over(ct, bg)) : tr_over(ct, tr_over(cf, bg));
	} else if (df >= 0.0) {
		res = tr_over(cf, bg);
	} else if (dt >= 0.0) {
		res = tr_over(ct, bg);
	}
	return settle(res, uv);
}

void fragment() {
	COLOR = transition(UV);
}
