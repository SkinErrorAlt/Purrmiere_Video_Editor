shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int turns = 1;
uniform int axis = 0;
uniform int spin_way = 0;
uniform float depth : hint_range(0.0, 3.0) = 0.9;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
uniform bool motion_blur = true;
uniform float shutter : hint_range(0.0, 360.0) = 180.0;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

mat3 turn_m(float a) {
	float c = cos(a);
	float s = sin(a);
	if (axis == 1) {
		return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
	}
	return mat3(vec3(c, 0.0, s), vec3(0.0, 1.0, 0.0), vec3(-s, 0.0, c));
}

vec4 scene(vec2 uv, float p, out vec4 probe) {
	float e = tr_ease(p, 4);
	float total = TR_PI * (1.0 + 2.0 * float(turns));
	float a = total * e * (spin_way == 0 ? 1.0 : -1.0);
	mat3 m = turn_m(a);
	vec3 centre = vec3(0.0, 0.0, depth * sin(TR_PI * e));
	float d = tr_camera_distance(lens);
	vec3 ro = vec3(0.0, 0.0, -d);
	vec3 rd = normalize(vec3(tr_world(uv), 0.0) - ro);
	vec3 n = m * vec3(0.0, 0.0, -1.0);
	float dn = dot(rd, n);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	probe = vec4(0.0, 0.0, 0.0, 0.0);
	if (abs(dn) > 0.000001) {
		float t = dot(centre - ro, n) / dn;
		vec3 q = transpose(m) * (ro + rd * t - centre);
		if (t > 0.0 && abs(q.x) <= tr_ratio() * 0.5 && abs(q.y) <= 0.5) {
			bool front = dn < 0.0;
			vec2 lq = q.xy;
			if (!front) {
				if (axis == 1) {
					lq.y = -lq.y;
				} else {
					lq.x = -lq.x;
				}
			}
			vec2 cuv = tr_frame_uv(lq);
			probe = vec4(cuv, front ? 1.0 : 2.0, 1.0);
			vec4 c = front ? texture(from_tex, cuv) : texture(to_tex, cuv);
			return tr_over(tr_shade(c, mix(1.0, abs(n.z), shading)), bg);
		}
	}
	return bg;
}

vec2 to_px(vec3 w) {
	float d = tr_camera_distance(lens);
	return w.xy * d / max(d + w.z, 0.02) * frame_px.y;
}

vec3 card_point(float p, vec2 c) {
	float e = tr_ease(p, 4);
	float total = TR_PI * (1.0 + 2.0 * float(turns));
	float a = total * e * (spin_way == 0 ? 1.0 : -1.0);
	return vec3(0.0, 0.0, depth * sin(TR_PI * e)) + turn_m(a) * vec3(c, 0.0);
}

float corner_motion(float pa, float pb) {
	vec2 h = vec2(tr_ratio() * 0.5, 0.5);
	float m = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 c = vec2(i % 2 == 0 ? -h.x : h.x, i < 2 ? -h.y : h.y);
		m = max(m, length(to_px(card_point(pb, c)) - to_px(card_point(pa, c))));
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
	res = mix(res, from_at(uv), 1.0 - smoothstep(0.0, 0.03, progress));
	return mix(res, to_at(uv), smoothstep(0.97, 1.0, progress));
}

void fragment() {
	COLOR = transition(UV);
}
