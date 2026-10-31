shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int hinge = 0;
uniform int curve = 0;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
uniform float shadow : hint_range(0.0, 1.0) = 0.4;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

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

vec2 to_canon(vec2 w) {
	if (hinge == 1) {
		return vec2(w.x, -w.y);
	} else if (hinge == 2) {
		return vec2(w.y, w.x);
	} else if (hinge == 3) {
		return vec2(w.y, -w.x);
	}
	return w;
}

vec2 from_canon(vec2 c) {
	if (hinge == 1) {
		return vec2(c.x, -c.y);
	} else if (hinge == 2) {
		return vec2(c.y, c.x);
	} else if (hinge == 3) {
		return vec2(-c.y, c.x);
	}
	return c;
}

vec4 transition(vec2 uv) {
	float t = clamp(progress, 0.0, 1.0);
	float e = curve == 0 ? t * t * t : (curve == 1 ? t * t : tr_ease(t, 3));
	float a = e * TR_PI * 0.5;
	bool side = hinge >= 2;
	float half_x = side ? 0.5 : tr_ratio() * 0.5;
	float half_y = side ? tr_ratio() * 0.5 : 0.5;
	float d = tr_camera_distance(lens);
	vec3 ro = vec3(0.0, 0.0, -d);
	vec2 w = to_canon(tr_world(uv));
	vec3 rd = normalize(vec3(w, 0.0) - ro);
	vec3 pivot = vec3(0.0, -half_y, 0.0);
	vec3 up = vec3(0.0, cos(a), -sin(a));
	vec3 o = pivot + vec3(-half_x, 0.0, 0.0) + up * half_y * 2.0;
	vec3 ex = vec3(half_x * 2.0, 0.0, 0.0);
	vec3 ey = -up * half_y * 2.0;
	vec4 h = quad_hit(ro, rd, o, ex, ey);
	vec4 under = to_at(uv);
	float lift = sin(a) * (1.0 - e);
	float sh = shadow * lift * smoothstep(-half_y + 2.0 * half_y * cos(a) + 0.3, -half_y, w.y);
	under = tr_shade(under, 1.0 - 0.7 * sh);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	vec4 res = tr_over(under, bg);
	if (h.w > 0.0) {
		vec2 cw = vec2(-half_x + h.x * half_x * 2.0, half_y - h.y * half_y * 2.0);
		vec2 cuv = tr_frame_uv(from_canon(cw));
		vec4 c = texture(from_tex, cuv);
		vec3 n = normalize(cross(ex, ey));
		float light = mix(1.0, clamp(abs(dot(n, normalize(vec3(0.0, 0.6, -1.0)))) / 0.8575, 0.0, 1.0), shading);
		if (h.z < 0.0) {
			light *= 0.8;
		}
		res = tr_over(tr_shade(c, light), res);
	}
	return settle(res, uv);
}

void fragment() {
	COLOR = transition(UV);
}
