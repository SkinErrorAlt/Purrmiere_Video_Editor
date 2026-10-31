shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float pull_back : hint_range(0.0, 1.0) = 0.35;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
uniform bool motion_blur = false;
uniform float shutter : hint_range(0.0, 360.0) = 180.0;
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

vec4 wing(vec3 ro, vec3 rd, vec3 pole, vec3 dir, float len, bool use_from, bool mirror, out float dist, out vec2 cuv) {
	vec3 o = pole + vec3(0.0, 0.5, 0.0);
	vec3 ex = dir * len;
	vec3 ey = vec3(0.0, -1.0, 0.0);
	vec4 h = quad_hit(ro, rd, o, ex, ey);
	dist = h.w;
	cuv = vec2(0.0);
	if (h.w < 0.0) {
		return vec4(0.0);
	}
	cuv = h.xy;
	if (h.z < 0.0) {
		cuv.x = 1.0 - cuv.x;
	}
	if (mirror) {
		cuv.x = 1.0 - cuv.x;
	}
	vec4 c = use_from ? texture(from_tex, cuv) : texture(to_tex, cuv);
	vec3 n = normalize(cross(ex, ey));
	float light = mix(1.0, clamp(abs(dot(n, normalize(vec3(0.35, 0.0, -1.0)))) * 1.06, 0.0, 1.0), shading);
	return tr_shade(c, light);
}

vec4 scene(vec2 uv, float p, out vec4 probe) {
	float e = tr_ease(p, 4);
	float b = e * TR_PI * 0.5;
	float hw = tr_ratio() * 0.5;
	float d = tr_camera_distance(lens);
	vec3 ro = vec3(0.0, 0.0, -d);
	vec2 w = tr_world(uv);
	bool mirror = direction == 1;
	if (mirror) {
		w.x = -w.x;
	}
	vec3 rd = normalize(vec3(w, 0.0) - ro);
	float back = pull_back * 1.6 * sin(TR_PI * e);
	vec3 pole = vec3(-hw, 0.0, back);
	float df;
	float dt;
	vec2 uf;
	vec2 ut;
	vec4 cf = wing(ro, rd, pole, vec3(cos(b), 0.0, -sin(b)), hw * 2.0, true, mirror, df, uf);
	vec4 ct = wing(ro, rd, pole, vec3(sin(b), 0.0, cos(b)), hw * 2.0, false, mirror, dt, ut);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	probe = vec4(0.0);
	vec4 res = bg;
	if (df >= 0.0 && dt >= 0.0) {
		res = df < dt ? tr_over(cf, tr_over(ct, bg)) : tr_over(ct, tr_over(cf, bg));
		probe = df < dt ? vec4(uf, 1.0, 1.0) : vec4(ut, 2.0, 1.0);
	} else if (df >= 0.0) {
		res = tr_over(cf, bg);
		probe = vec4(uf, 1.0, 1.0);
	} else if (dt >= 0.0) {
		res = tr_over(ct, bg);
		probe = vec4(ut, 2.0, 1.0);
	}
	return res;
}

vec2 to_px(vec3 w) {
	float d = tr_camera_distance(lens);
	return w.xy * d / max(d + w.z, 0.02) * frame_px.y;
}

vec3 door_point(float p, int k) {
	float e = tr_ease(p, 4);
	float b = e * TR_PI * 0.5;
	float hw = tr_ratio() * 0.5;
	vec3 pole = vec3(-hw, 0.0, pull_back * 1.6 * sin(TR_PI * e));
	float y = (k % 2 == 0) ? 0.5 : -0.5;
	if (k < 2) {
		return pole + vec3(0.0, y, 0.0);
	} else if (k < 4) {
		return pole + vec3(cos(b), 0.0, -sin(b)) * hw * 2.0 + vec3(0.0, y, 0.0);
	}
	return pole + vec3(sin(b), 0.0, cos(b)) * hw * 2.0 + vec3(0.0, y, 0.0);
}

float corner_motion(float pa, float pb) {
	float m = 0.0;
	for (int k = 0; k < 6; k++) {
		m = max(m, length(to_px(door_point(pb, k)) - to_px(door_point(pa, k))));
	}
	return m;
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	vec4 probe;
	vec4 res = scene(uv, p, probe);
	float window = shutter / 360.0 / (30.0 * max(duration, 0.05));
	float half_w = min(window * 0.5, min(p, 1.0 - p));
	if (motion_blur && half_w > 0.00001) {
		float pa = p - half_w;
		float pb = p + half_w;
		float motion = corner_motion(pa, pb);
		int n = int(clamp(ceil(motion / 3.0) * 2.0, 2.0, 64.0));
		if (motion > 0.75) {
			vec2 px = uv * frame_px;
			float jitter = fract(52.9829189 * fract(0.06711056 * px.x + 0.00583715 * px.y));
			vec4 sum = vec4(0.0);
			for (int i = 0; i < 64; i++) {
				if (i >= n) {
					break;
				}
				vec4 dummy;
				float off = (i % 2 == 0) ? jitter : 1.0 - jitter;
				sum += scene(uv, mix(pa, pb, (float(i) + off) / float(n)), dummy);
			}
			res = sum / float(n);
		}
	}
	return settle(res, uv);
}

void fragment() {
	COLOR = transition(UV);
}
