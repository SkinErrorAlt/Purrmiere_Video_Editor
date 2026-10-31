shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform int direction = 0;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float pull_back : hint_range(0.0, 1.0) = 0.15;
uniform float shading : hint_range(0.0, 1.0) = 0.5;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float motion_blur : hint_range(0.0, 2.0) = 0.0;
uniform float shutter : hint_range(0.0, 360.0) = 180.0;

vec3 cam_eye() {
	return vec3(0.0, 0.0, -tr_camera_distance(lens));
}

vec3 cam_dir(vec2 uv) {
	return normalize(vec3(tr_world(uv), 0.0) - cam_eye());
}

vec4 plane_cast(vec3 ro, vec3 rd, mat3 r, vec3 pos) {
	vec3 o = transpose(r) * (ro - pos);
	vec3 d = transpose(r) * rd;
	float t = abs(d.z) < 0.000001 ? -1.0 : -o.z / d.z;
	vec3 h = o + d * max(t, 0.0);
	return vec4(h.x / tr_ratio() + 0.5, 0.5 - h.y, d.z > 0.0 ? 1.0 : -1.0, t);
}

vec3 pivot_place(mat3 r, vec3 pivot, vec3 offset) {
	return pivot - r * pivot + offset;
}

float box_cover(vec4 hit, vec4 box) {
	vec2 fw = max(fwidth(hit.xy), vec2(0.00001));
	vec2 lo = (hit.xy - box.xy) / fw;
	vec2 hi = (box.zw - hit.xy) / fw;
	float c = clamp(min(min(lo.x, lo.y), min(hi.x, hi.y)) + 0.5, 0.0, 1.0);
	return hit.w > 0.0 ? c : 0.0;
}

float edge_cover(vec4 hit) {
	return box_cover(hit, vec4(0.0, 0.0, 1.0, 1.0));
}

float face_light(mat3 r) {
	return mix(1.0, abs((r * vec3(0.0, 0.0, -1.0)).z), shading);
}

vec4 bg_fill() {
	float w = clamp(min(progress, 1.0 - progress) * 25.0, 0.0, 1.0);
	return vec4(background.rgb * background.a, background.a) * w;
}

vec4 near_over(vec4 ca, float da, vec4 cb, float db) {
	if (da < 0.0 || ca.a <= 0.0) {
		return cb;
	}
	if (db < 0.0 || cb.a <= 0.0) {
		return ca;
	}
	return da <= db ? tr_over(ca, cb) : tr_over(cb, ca);
}

vec4 scene(vec2 uv, float pr) {
	float e = tr_ease(pr, 3);
	bool sideways = direction < 2;
	float half_d = sideways ? tr_ratio() * 0.5 : 0.5;
	float s = (direction == 0 || direction == 3) ? 1.0 : -1.0;
	vec3 axis = sideways ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 pivot = vec3(0.0, 0.0, -half_d);
	vec3 off = vec3(0.0, 0.0, sin(e * TR_PI) * pull_back * half_d);
	mat3 rf = tr_rotation(axis * (-90.0 * e * s));
	mat3 rt = tr_rotation(axis * (90.0 * (1.0 - e) * s));
	vec3 ro = cam_eye();
	vec3 rd = cam_dir(uv);
	vec4 hf = plane_cast(ro, rd, rf, pivot_place(rf, pivot, off));
	vec4 ht = plane_cast(ro, rd, rt, pivot_place(rt, pivot, off));
	float cf = edge_cover(hf);
	float ct = edge_cover(ht);
	cf = hf.z > 0.0 ? cf : 0.0;
	ct = ht.z > 0.0 ? ct : 0.0;
	vec4 colf = tr_shade(texture(from_tex, hf.xy), face_light(rf)) * cf;
	vec4 colt = tr_shade(texture(to_tex, ht.xy), face_light(rt)) * ct;
	return tr_over(near_over(colf, cf > 0.0 ? hf.w : -1.0, colt, ct > 0.0 ? ht.w : -1.0), bg_fill());
}

float blur_jitter(vec2 uv) {
	vec2 q = floor(uv * frame_px);
	vec3 p3 = fract(vec3(q.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec4 transition(vec2 uv) {
	float w = motion_blur * 0.22 * shutter / 360.0 / (30.0 * max(duration, 0.05));
	float edge = min(progress, 1.0 - progress);
	w *= smoothstep(0.05, 0.45, edge);
	w = min(w, 2.0 * edge);
	if (w <= 0.000001) {
		return scene(uv, progress);
	}
	float j = blur_jitter(uv);
	vec4 acc = vec4(0.0);
	for (int i = 0; i < 32; i++) {
		acc += scene(uv, progress + w * ((float(i) + j) / 32.0 - 0.5));
	}
	return acc / 32.0;
}

void fragment() {
	COLOR = transition(UV);
}
