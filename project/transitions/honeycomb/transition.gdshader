shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float cells : hint_range(3.0, 30.0) = 9.0;
uniform int pattern = 0;
uniform float spin : hint_range(0.0, 180.0) = 90.0;
uniform float bevel : hint_range(0.0, 0.5) = 0.18;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

const float SQ3 = 1.7320508;

mat3 axis_rot(vec3 k, float a) {
	float c = cos(a);
	float s = sin(a);
	mat3 kx = mat3(vec3(0.0, k.z, -k.y), vec3(-k.z, 0.0, k.x), vec3(k.y, -k.x, 0.0));
	return mat3(1.0) * c + kx * s + outerProduct(k, k) * (1.0 - c);
}

vec2 hex_cell(vec2 p, float s) {
	float q = (SQ3 / 3.0 * p.x - p.y / 3.0) / s;
	float r = (2.0 / 3.0 * p.y) / s;
	vec3 cube = vec3(q, r, -q - r);
	vec3 rc = floor(cube + 0.5);
	vec3 df = abs(rc - cube);
	if (df.x > df.y && df.x > df.z) {
		rc.x = -rc.y - rc.z;
	} else if (df.y > df.z) {
		rc.y = -rc.x - rc.z;
	}
	return rc.xy;
}

vec2 hex_centre(vec2 qr, float s) {
	return vec2(s * SQ3 * (qr.x + qr.y * 0.5), s * 1.5 * qr.y);
}

float hex_edge(vec2 l, float s) {
	vec2 a = abs(l);
	return max(a.x, a.x * 0.5 + a.y * SQ3 * 0.5) / (s * SQ3 * 0.5);
}

vec4 settle(vec4 c, vec2 uv) {
	c = mix(c, from_at(uv), 1.0 - smoothstep(0.0, 0.03, progress));
	return mix(c, to_at(uv), smoothstep(0.97, 1.0, progress));
}

vec4 cell_card(vec3 ro, vec3 rd, vec2 cc, vec2 home, float s, mat3 m, float scale, float back, bool use_from, float edge_amt, out float dist) {
	dist = -1.0;
	vec3 centre = vec3(cc, back);
	vec3 n = m * vec3(0.0, 0.0, -1.0);
	float dn = dot(rd, n);
	if (abs(dn) < 0.000001) {
		return vec4(0.0);
	}
	float t = dot(centre - ro, n) / dn;
	if (t <= 0.0 || dn > 0.0) {
		return vec4(0.0);
	}
	vec3 q = transpose(m) * (ro + rd * t - centre) / max(scale, 0.0001);
	float e = hex_edge(q.xy, s);
	if (e > 1.0) {
		return vec4(0.0);
	}
	dist = t;
	vec2 uv = tr_frame_uv(home + q.xy);
	vec4 c = use_from ? texture(from_tex, uv) : texture(to_tex, uv);
	float light = mix(1.0, abs(n.z), shading);
	float rim = smoothstep(1.0 - bevel, 1.0, e) * edge_amt;
	light *= 1.0 - 0.55 * rim;
	return tr_shade(c, light);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float s = tr_ratio() / max(cells, 1.0) / SQ3;
	vec2 w = tr_world(uv);
	vec2 qr = hex_cell(w, s);
	vec2 cc = hex_centre(qr, s);
	float rnd = tr_hash(qr + 3.7);
	float order = rnd;
	if (pattern == 1) {
		order = mix(length(cc) / (0.5 * length(vec2(tr_ratio(), 1.0))), rnd, 0.25);
	} else if (pattern == 2) {
		order = mix(cc.x / tr_ratio() + 0.5, rnd, 0.25);
	} else if (pattern == 3) {
		order = mix(0.5 - cc.y, rnd, 0.25);
	}
	order = clamp(order, 0.0, 1.0);
	float u = clamp((p - 0.45 * order) / 0.55, 0.0, 1.0);
	float phi = tr_hash(qr + 11.3) * TR_PI * 2.0;
	vec3 axis = vec3(cos(phi), sin(phi), 0.0);
	float d = tr_camera_distance(lens);
	vec3 ro = vec3(0.0, 0.0, -d);
	vec3 rd = normalize(vec3(w, 0.0) - ro);
	float uo = clamp(u / 0.6, 0.0, 1.0);
	float un = clamp((u - 0.4) / 0.6, 0.0, 1.0);
	float eo = uo * uo;
	float en = 1.0 - (1.0 - un) * (1.0 - un);
	float a_spin = radians(spin);
	float df = -1.0;
	float dt = -1.0;
	vec4 cf = vec4(0.0);
	vec4 ct = vec4(0.0);
	if (uo < 1.0) {
		float sc = 1.0 - 0.25 * eo;
		cf = cell_card(ro, rd, cc * (1.0 + 0.9 * eo / d), cc, s, axis_rot(axis, a_spin * eo), sc, 0.9 * eo, true, sin(TR_PI * min(u * 1.5, 1.0)), df);
		cf *= 1.0 - smoothstep(0.75, 1.0, uo);
	}
	if (un > 0.0) {
		float sc = 0.75 + 0.25 * en;
		ct = cell_card(ro, rd, cc * (1.0 + 0.6 * (1.0 - en) / d), cc, s, axis_rot(axis, -a_spin * (1.0 - en)), sc, 0.6 * (1.0 - en), false, sin(TR_PI * u), dt);
		ct *= smoothstep(0.0, 0.25, un);
	}
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
