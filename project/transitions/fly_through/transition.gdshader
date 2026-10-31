shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform int mode = 0;
uniform float travel : hint_range(0.5, 6.0) = 3.0;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
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

vec4 flat_card(vec3 ro, vec3 rd, float z, bool use_from, out float dist) {
	vec4 h = plane_cast(ro, rd, mat3(1.0), vec3(0.0, 0.0, z));
	float cov = edge_cover(h);
	dist = cov > 0.0 ? h.w : -1.0;
	vec4 c = use_from ? texture(from_tex, h.xy) : texture(to_tex, h.xy);
	return c * cov;
}

vec4 transition(vec2 uv) {
	bool inward = mode < 2;
	bool bounce = mode == 1 || mode == 3;
	float cd = tr_camera_distance(lens);
	float a1 = clamp(progress / 0.6, 0.0, 1.0);
	float e1 = tr_ease(a1, 1);
	float a2 = clamp((progress - 0.3) / 0.7, 0.0, 1.0);
	float e2 = tr_ease(a2, bounce ? 5 : 2);
	float zf = inward ? -0.8 * cd * e1 : travel * e1;
	float zt = inward ? travel * (1.0 - e2) : -0.8 * cd * (1.0 - e2);
	float af = 1.0 - smoothstep(0.0, 1.0, a1);
	float at = smoothstep(0.0, 1.0, clamp(a2 * 2.5, 0.0, 1.0));
	vec3 ro = cam_eye();
	vec3 rd = cam_dir(uv);
	float df;
	float dt;
	vec4 cf = flat_card(ro, rd, zf, true, df) * af;
	vec4 ct = flat_card(ro, rd, zt, false, dt) * at;
	return tr_over(near_over(cf, df, ct, dt), bg_fill());
}

void fragment() {
	COLOR = transition(UV);
}
