shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform int direction = 3;
uniform float wobble : hint_range(0.0, 1.0) = 0.8;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float pull_back : hint_range(0.0, 1.0) = 0.15;
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

float flop_turn(float t) {
	float land = 0.62;
	float x = clamp(t / land, 0.0, 1.0);
	float base = x * x * (3.0 - x) * 0.5;
	float u = clamp((t - land) / (1.0 - land), 0.0, 1.0);
	float amp = 1.5 * (1.0 - land) / (land * 3.0 * TR_PI);
	return base + wobble * amp * sin(u * 3.0 * TR_PI) * (1.0 - u) * (1.0 - u);
}

vec4 transition(vec2 uv) {
	float turn = flop_turn(progress);
	bool sideways = direction < 2;
	float s = (direction == 1 || direction == 2) ? 1.0 : -1.0;
	float angle = 180.0 * turn * s;
	vec3 rot = sideways ? vec3(0.0, angle, 0.0) : vec3(angle, 0.0, 0.0);
	float span = sideways ? tr_ratio() : 1.0;
	mat3 r = tr_rotation(rot);
	vec3 pos = vec3(0.0, 0.0, sin(clamp(turn, 0.0, 1.0) * TR_PI) * pull_back * span * 0.8);
	vec4 hit = plane_cast(cam_eye(), cam_dir(uv), r, pos);
	float cov = edge_cover(hit);
	vec2 cuv = hit.xy;
	vec4 c;
	if (hit.z > 0.0) {
		c = texture(from_tex, cuv);
	} else {
		cuv = sideways ? vec2(1.0 - cuv.x, cuv.y) : vec2(cuv.x, 1.0 - cuv.y);
		c = texture(to_tex, cuv);
	}
	c = tr_shade(c, face_light(r));
	return tr_over(c * cov, bg_fill());
}

void fragment() {
	COLOR = transition(UV);
}
