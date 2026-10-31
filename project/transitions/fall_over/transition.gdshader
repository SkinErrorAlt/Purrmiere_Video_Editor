shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform int direction = 0;
uniform float twist : hint_range(0.0, 30.0) = 12.0;
uniform float shadow : hint_range(0.0, 1.0) = 0.5;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
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

vec4 transition(vec2 uv) {
	float t = progress;
	float s = direction == 0 ? 1.0 : -1.0;
	float e = pow(t, 2.2);
	mat3 r = tr_rotation(vec3(88.0 * e, -s * twist * 0.5 * e, s * twist * e));
	vec3 pos = pivot_place(r, vec3(0.0, -0.5, 0.0), vec3(0.0));
	vec4 h = plane_cast(cam_eye(), cam_dir(uv), r, pos);
	float cov = edge_cover(h) * (1.0 - smoothstep(0.78, 1.0, t));
	vec4 top = tr_shade(texture(from_tex, h.xy), face_light(r)) * cov;
	float dim = 1.0 - shadow * (1.0 - smoothstep(0.0, 1.0, t));
	vec4 under = tr_shade(to_at(uv), dim) * clamp(t * 25.0, 0.0, 1.0);
	return tr_over(top, tr_over(under, bg_fill()));
}

void fragment() {
	COLOR = transition(UV);
}
