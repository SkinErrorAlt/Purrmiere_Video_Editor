shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int panels : hint_range(2, 12) = 4;
uniform int direction = 0;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.7;
uniform float shadow : hint_range(0.0, 1.0) = 0.4;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec3 to_canon(vec3 v) {
	if (direction == 1) {
		return vec3(-v.x, v.y, v.z);
	} else if (direction == 2) {
		return vec3(-v.y, v.x, v.z);
	} else if (direction == 3) {
		return vec3(v.y, v.x, v.z);
	}
	return v;
}

vec2 from_canon(vec2 c) {
	if (direction == 1) {
		return vec2(-c.x, c.y);
	} else if (direction == 2) {
		return vec2(c.y, -c.x);
	} else if (direction == 3) {
		return vec2(c.y, c.x);
	}
	return c;
}

vec4 quad_hit(vec3 ro, vec3 rd, vec3 o, vec3 ex, vec3 ey) {
	vec3 n = cross(ex, ey);
	float dn = dot(rd, n);
	if (abs(dn) < 0.0000001) {
		return vec4(0.0, 0.0, 0.0, -1.0);
	}
	float t = dot(o - ro, n) / dn;
	vec3 q = ro + rd * t - o;
	vec2 st = vec2(dot(q, ex) / max(dot(ex, ex), 0.0000001), dot(q, ey) / dot(ey, ey));
	if (t <= 0.0 || st.x < 0.0 || st.y < 0.0 || st.x > 1.0 || st.y > 1.0) {
		return vec4(st, 0.0, -1.0);
	}
	return vec4(st, dn < 0.0 ? 1.0 : -1.0, t);
}

vec4 transition(vec2 uv) {
	float e = tr_ease(progress, 3);
	float th = e * TR_PI * 0.5;
	bool across = direction >= 2;
	float len = across ? 1.0 : tr_ratio();
	float hgt = across ? tr_ratio() : 1.0;
	float n_p = float(panels);
	float pw = len / n_p;
	float d = tr_camera_distance(lens);
	vec3 ro = to_canon(vec3(0.0, 0.0, -d));
	vec3 rd = to_canon(normalize(vec3(tr_world(uv), 0.0) - vec3(0.0, 0.0, -d)));
	vec3 light_dir = normalize(vec3(-0.9, 0.2, -0.6));
	float rest = dot(vec3(0.0, 0.0, -1.0), light_dir);
	float best = 1000000.0;
	vec4 top = vec4(0.0);
	float cover = 0.0;
	for (int k = 0; k < 12; k++) {
		if (k >= panels) {
			break;
		}
		float kf = float(k);
		vec3 a = vec3(-len * 0.5 + kf * pw * cos(th), hgt * 0.5, mod(kf, 2.0) > 0.5 ? -pw * sin(th) : 0.0);
		vec3 b = vec3(-len * 0.5 + (kf + 1.0) * pw * cos(th), hgt * 0.5, mod(kf + 1.0, 2.0) > 0.5 ? -pw * sin(th) : 0.0);
		vec3 ex = b - a;
		vec3 ey = vec3(0.0, -hgt, 0.0);
		vec4 h = quad_hit(ro, rd, a, ex, ey);
		if (h.w > 0.0 && h.w < best) {
			best = h.w;
			vec2 cw = vec2(-len * 0.5 + (kf + h.x) * pw, hgt * 0.5 - h.y * hgt);
			vec4 c = texture(from_tex, tr_frame_uv(from_canon(cw)));
			vec3 nrm = normalize(cross(ex, ey));
			if (nrm.z > 0.0) {
				nrm = -nrm;
			}
			float light = clamp((0.3 + 0.7 * max(dot(nrm, light_dir), 0.0)) / (0.3 + 0.7 * rest), 0.0, 1.15);
			top = tr_shade(c, mix(1.0, light, shading));
			cover = 1.0;
		}
	}
	vec4 under = to_at(uv);
	vec3 cw3 = ro + rd * (-ro.z / rd.z);
	float edge = -len * 0.5 + len * cos(th);
	float sh = shadow * sin(th) * (1.0 - smoothstep(edge, edge + 0.25 * sin(th) + 0.001, cw3.x));
	under = tr_shade(under, 1.0 - 0.6 * sh);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	vec4 res = tr_over(top, tr_over(under, bg));
	res = mix(res, from_at(uv), 1.0 - smoothstep(0.0, 0.03, progress));
	return mix(res, to_at(uv), smoothstep(0.97, 1.0, progress));
}

void fragment() {
	COLOR = transition(UV);
}
