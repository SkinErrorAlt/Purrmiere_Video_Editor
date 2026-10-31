shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform int direction = 0;
uniform float radius : hint_range(0.6, 3.0) = 1.2;
uniform float pull_back : hint_range(0.0, 2.0) = 0.5;
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

vec4 near_over(vec4 ca, float da, vec4 cb, float db) {
	if (da < 0.0 || ca.a <= 0.0) {
		return cb;
	}
	if (db < 0.0 || cb.a <= 0.0) {
		return ca;
	}
	return da <= db ? tr_over(ca, cb) : tr_over(cb, ca);
}

vec4 ride(vec3 ro, vec3 rd, float phi, float rr, float k, bool sideways, bool use_from, out float dist) {
	vec3 pos;
	mat3 r;
	if (sideways) {
		pos = vec3(rr * sin(phi), 0.0, rr - rr * cos(phi) + pull_back * k);
		r = tr_rotation(vec3(0.0, -degrees(phi), 0.0));
	} else {
		pos = vec3(0.0, rr * sin(phi), rr - rr * cos(phi) + pull_back * k);
		r = tr_rotation(vec3(degrees(phi), 0.0, 0.0));
	}
	vec4 h = plane_cast(ro, rd, r, pos);
	float cov = edge_cover(h);
	dist = cov > 0.0 ? h.w : -1.0;
	vec2 cuv = h.xy;
	float light = face_light(r);
	if (h.z < 0.0) {
		cuv = sideways ? vec2(1.0 - cuv.x, cuv.y) : vec2(cuv.x, 1.0 - cuv.y);
		light *= 0.4;
	}
	vec4 c = use_from ? texture(from_tex, cuv) : texture(to_tex, cuv);
	return tr_shade(c, light) * cov;
}

vec4 transition(vec2 uv) {
	float t = progress;
	bool sideways = direction < 2;
	float s = (direction == 0 || direction == 2) ? 1.0 : -1.0;
	float span = sideways ? tr_ratio() : 1.0;
	float rr = radius * span;
	float e = tr_ease(t, 3);
	float k = sin(t * TR_PI);
	float gap_angle = 2.0 * asin(min(0.99, span * 0.56 / rr));
	vec3 ro = cam_eye();
	vec3 rd = cam_dir(uv);
	float df;
	float dt;
	vec4 cf = ride(ro, rd, -s * gap_angle * e, rr, k, sideways, true, df) * clamp((1.0 - t) * 25.0, 0.0, 1.0);
	vec4 ct = ride(ro, rd, s * gap_angle * (1.0 - e), rr, k, sideways, false, dt) * clamp(t * 25.0, 0.0, 1.0);
	return tr_over(near_over(cf, df, ct, dt), bg_fill());
}

void fragment() {
	COLOR = transition(UV);
}
