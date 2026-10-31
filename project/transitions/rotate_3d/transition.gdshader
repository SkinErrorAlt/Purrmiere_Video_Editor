shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform int direction = 0;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float pull_back : hint_range(0.0, 1.0) = 0.3;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
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

vec4 scene(vec2 uv, float pr) {
	bool sideways = direction < 2;
	float s = (direction == 1 || direction == 2) ? 1.0 : -1.0;
	bool first = pr < 0.5;
	float a = first ? 90.0 * tr_ease(pr * 2.0, 1) : -90.0 * (1.0 - tr_ease(pr * 2.0 - 1.0, 2));
	float angle = a * s;
	vec3 rot = sideways ? vec3(0.0, angle, 0.0) : vec3(angle, 0.0, 0.0);
	float span = sideways ? tr_ratio() : 1.0;
	mat3 r = tr_rotation(rot);
	vec3 pos = vec3(0.0, 0.0, sin(tr_ease(pr, 3) * TR_PI) * pull_back * span * 0.6);
	vec4 hit = plane_cast(cam_eye(), cam_dir(uv), r, pos);
	float cov = edge_cover(hit);
	vec4 c = first ? texture(from_tex, hit.xy) : texture(to_tex, hit.xy);
	c = tr_shade(c, face_light(r));
	return tr_over(c * cov, bg_fill());
}

float blur_jitter(vec2 uv) {
	vec2 q = floor(uv * frame_px);
	vec3 p3 = fract(vec3(q.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec4 transition(vec2 uv) {
	float w = motion_blur * 1.0 * shutter / 360.0 / (30.0 * max(duration, 0.05));
	float edge = min(progress, 1.0 - progress);
	w *= smoothstep(0.05, 0.45, edge);
	w = min(w, 2.0 * edge);
	if (w <= 0.000001) {
		return scene(uv, progress);
	}
	float j = blur_jitter(uv);
	vec4 acc = vec4(0.0);
	for (int i = 0; i < 24; i++) {
		acc += scene(uv, progress + w * ((float(i) + j) / 24.0 - 0.5));
	}
	return acc / 24.0;
}

void fragment() {
	COLOR = transition(UV);
}
