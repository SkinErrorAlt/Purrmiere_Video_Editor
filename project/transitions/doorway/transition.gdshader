shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform int split = 0;
uniform int swing = 1;
uniform float open : hint_range(60.0, 150.0) = 100.0;
uniform float depth : hint_range(0.0, 4.0) = 1.0;
uniform float reflection : hint_range(0.0, 1.0) = 0.25;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.5;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

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

vec4 compose3(vec4 c0, float d0, vec4 c1, float d1, vec4 c2, float d2) {
	float e0 = (d0 < 0.0 || c0.a <= 0.0) ? 1e9 : d0;
	float e1 = (d1 < 0.0 || c1.a <= 0.0) ? 1e9 : d1;
	float e2 = (d2 < 0.0 || c2.a <= 0.0) ? 1e9 : d2;
	vec4 t;
	float s;
	if (e1 < e0) {
		t = c0; c0 = c1; c1 = t;
		s = e0; e0 = e1; e1 = s;
	}
	if (e2 < e1) {
		t = c1; c1 = c2; c2 = t;
		s = e1; e1 = e2; e2 = s;
	}
	if (e1 < e0) {
		t = c0; c0 = c1; c1 = t;
	}
	return tr_over(c0, tr_over(c1, c2));
}

vec4 door(vec3 ro, vec3 rd, mat3 r, vec3 pivot, vec4 box, out float dist) {
	vec4 h = plane_cast(ro, rd, r, pivot_place(r, pivot, vec3(0.0)));
	float cov = box_cover(h, box);
	dist = cov > 0.0 ? h.w : -1.0;
	float light = face_light(r);
	if (h.z < 0.0) {
		light *= 0.4;
	}
	return tr_shade(texture(from_tex, h.xy), light) * cov;
}

vec4 transition(vec2 uv) {
	float t = progress;
	float eo = tr_ease(t, 3);
	float ei = tr_ease(t, 3);
	float sw = swing == 0 ? -1.0 : 1.0;
	bool sideways = split == 0;
	float hw = tr_ratio() * 0.5;
	float a = open * eo * sw;
	mat3 ra;
	mat3 rb;
	vec3 pa;
	vec3 pb;
	vec4 ba;
	vec4 bb;
	if (sideways) {
		ra = tr_rotation(vec3(0.0, a, 0.0));
		rb = tr_rotation(vec3(0.0, -a, 0.0));
		pa = vec3(-hw, 0.0, 0.0);
		pb = vec3(hw, 0.0, 0.0);
		ba = vec4(0.0, 0.0, 0.5, 1.0);
		bb = vec4(0.5, 0.0, 1.0, 1.0);
	} else {
		ra = tr_rotation(vec3(a, 0.0, 0.0));
		rb = tr_rotation(vec3(-a, 0.0, 0.0));
		pa = vec3(0.0, 0.5, 0.0);
		pb = vec3(0.0, -0.5, 0.0);
		ba = vec4(0.0, 0.0, 1.0, 0.5);
		bb = vec4(0.0, 0.5, 1.0, 1.0);
	}
	vec3 ro = cam_eye();
	vec3 rd = cam_dir(uv);
	float da;
	float db;
	float vd = clamp((1.0 - t) * 25.0, 0.0, 1.0);
	vec4 ca = door(ro, rd, ra, pa, ba, da) * vd;
	vec4 cb = door(ro, rd, rb, pb, bb, db) * vd;
	vec3 pt = vec3(0.0, 0.0, depth * (1.0 - ei));
	vec4 ht = plane_cast(ro, rd, mat3(1.0), pt);
	float ct = edge_cover(ht) * clamp(t * 25.0, 0.0, 1.0);
	float glow = mix(1.0, mix(0.3, 1.0, smoothstep(0.0, 0.8, t)), shading);
	vec4 colt = tr_shade(texture(to_tex, ht.xy), glow) * ct;
	vec4 hr = plane_cast(ro, rd, mat3(1.0), pt + vec3(0.0, -1.0, 0.0));
	float cr = edge_cover(hr) * clamp(t * 25.0, 0.0, 1.0);
	float fade = clamp(1.0 - hr.y * 1.6, 0.0, 1.0);
	vec4 colr = tr_shade(texture(to_tex, vec2(hr.x, 1.0 - hr.y)), glow) * cr * reflection * fade * fade;
	vec4 scene = compose3(ca, da, cb, db, colt, ct > 0.0 ? ht.w : -1.0);
	return tr_over(scene, tr_over(colr, bg_fill()));
}

void fragment() {
	COLOR = transition(UV);
}
