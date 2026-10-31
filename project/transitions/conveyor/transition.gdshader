shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform int direction = 0;
uniform float angle : hint_range(0.0, 80.0) = 40.0;
uniform float bend : hint_range(0.0, 2.0) = 0.6;
uniform float pull_back : hint_range(0.0, 2.0) = 0.7;
uniform float gap : hint_range(0.0, 0.5) = 0.15;
uniform float reflection : hint_range(0.0, 1.0) = 0.3;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.4;
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

vec4 near_over(vec4 ca, float da, vec4 cb, float db) {
	if (da < 0.0 || ca.a <= 0.0) {
		return cb;
	}
	if (db < 0.0 || cb.a <= 0.0) {
		return ca;
	}
	return da <= db ? tr_over(ca, cb) : tr_over(cb, ca);
}

vec4 reflect_card(vec3 ro, vec3 rd, mat3 r, vec3 pos, bool use_from, out float dist) {
	vec4 h = plane_cast(ro, rd, r, pos + vec3(0.0, -1.0, 0.0));
	float cov = edge_cover(h);
	dist = cov > 0.0 ? h.w : -1.0;
	vec2 cuv = vec2(h.x, 1.0 - h.y);
	if (h.z < 0.0) {
		cuv.x = 1.0 - cuv.x;
	}
	vec4 c = use_from ? texture(from_tex, cuv) : texture(to_tex, cuv);
	float fade = clamp(1.0 - h.y * 1.6, 0.0, 1.0);
	return c * cov * reflection * fade * fade;
}

vec4 show_card(vec3 ro, vec3 rd, mat3 r, vec3 pos, bool use_from, out float dist) {
	vec4 h = plane_cast(ro, rd, r, pos);
	float cov = edge_cover(h);
	dist = cov > 0.0 ? h.w : -1.0;
	vec2 cuv = h.xy;
	float light = face_light(r);
	if (h.z < 0.0) {
		cuv.x = 1.0 - cuv.x;
		light *= 0.45;
	}
	vec4 c = use_from ? texture(from_tex, cuv) : texture(to_tex, cuv);
	return tr_shade(c, light) * cov;
}

void belt(float u, float k, float s, out mat3 r, out vec3 pos) {
	float pitch = tr_ratio() * (1.0 + gap);
	r = tr_rotation(vec3(0.0, -s * angle * u * k, 0.0));
	pos = vec3(s * u * pitch, 0.0, pull_back * k + bend * k * u * u);
}

vec4 transition(vec2 uv) {
	float t = progress;
	float s = direction == 0 ? 1.0 : -1.0;
	float k = smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.7, 1.0, t));
	float e = tr_ease(clamp((t - 0.1) / 0.8, 0.0, 1.0), 3);
	mat3 rf;
	mat3 rt;
	vec3 pf;
	vec3 pt;
	belt(-e, k, s, rf, pf);
	belt(1.0 - e, k, s, rt, pt);
	vec3 ro = cam_eye();
	vec3 rd = cam_dir(uv);
	float df;
	float dt;
	float gf;
	float gt;
	vec4 cf = show_card(ro, rd, rf, pf, true, df);
	vec4 ct = show_card(ro, rd, rt, pt, false, dt);
	vec4 mf = reflect_card(ro, rd, rf, pf, true, gf);
	vec4 mt = reflect_card(ro, rd, rt, pt, false, gt);
	return tr_over(near_over(cf, df, ct, dt), tr_over(near_over(mf, gf, mt, gt), bg_fill()));
}

void fragment() {
	COLOR = transition(UV);
}
