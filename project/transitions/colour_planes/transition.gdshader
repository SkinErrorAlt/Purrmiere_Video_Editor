shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float spread : hint_range(0.0, 1.0) = 0.35;
uniform float depth : hint_range(0.0, 2.0) = 0.6;
uniform float turn : hint_range(0.0, 60.0) = 18.0;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

mat3 rot_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, s), vec3(0.0, 1.0, 0.0), vec3(-s, 0.0, c));
}

vec4 plane(vec3 ro, vec3 rd, vec3 centre, mat3 m, bool use_from, bool mirror) {
	vec3 n = m * vec3(0.0, 0.0, -1.0);
	float dn = dot(rd, n);
	if (abs(dn) < 0.000001) {
		return vec4(0.0);
	}
	float t = dot(centre - ro, n) / dn;
	if (t <= 0.0) {
		return vec4(0.0);
	}
	vec3 q = transpose(m) * (ro + rd * t - centre);
	vec2 cuv = tr_frame_uv(q.xy);
	if (mirror) {
		cuv.x = 1.0 - cuv.x;
	}
	return use_from ? from_at(cuv) : to_at(cuv);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float sep = sin(TR_PI * tr_ease(p, 3));
	float wf = 1.0 - smoothstep(0.3, 0.7, p);
	float d = tr_camera_distance(lens);
	vec3 ro = vec3(0.0, 0.0, -d);
	vec2 w = tr_world(uv);
	bool mirror = direction == 1;
	if (mirror) {
		w.x = -w.x;
	}
	vec3 rd = normalize(vec3(w, 0.0) - ro);
	vec3 sum = vec3(0.0);
	float alpha = 0.0;
	for (int k = 0; k < 3; k++) {
		float kf = float(k) - 1.0;
		vec3 cf = vec3(kf * spread * tr_ratio() * 0.5 * sep, 0.0, (float(k) * 0.5 + 0.25) * depth * sep);
		vec3 ct = vec3(-cf.x, 0.0, cf.z);
		vec4 a = plane(ro, rd, cf, rot_y(radians(turn) * kf * sep), true, mirror);
		vec4 b = plane(ro, rd, ct, rot_y(-radians(turn) * kf * sep), false, mirror);
		float ca = k == 0 ? a.r : (k == 1 ? a.g : a.b);
		float cb = k == 0 ? b.r : (k == 1 ? b.g : b.b);
		float v = ca * wf + cb * (1.0 - wf);
		if (k == 0) {
			sum.r = v;
		} else if (k == 1) {
			sum.g = v;
		} else {
			sum.b = v;
		}
		alpha = max(alpha, a.a * wf + b.a * (1.0 - wf));
	}
	alpha = max(alpha, max(sum.r, max(sum.g, sum.b)));
	vec4 bg = vec4(background.rgb * background.a, background.a);
	vec4 res = vec4(sum, alpha) + bg * (1.0 - alpha);
	res = mix(res, from_at(uv), 1.0 - smoothstep(0.0, 0.03, progress));
	return mix(res, to_at(uv), smoothstep(0.97, 1.0, progress));
}

void fragment() {
	COLOR = transition(UV);
}
