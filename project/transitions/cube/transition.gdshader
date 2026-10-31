shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform int direction = 0;
uniform float depth : hint_range(10.0, 90.0) = 40.0;
uniform float pull_back : hint_range(0.0, 1.0) = 0.35;
uniform float shading : hint_range(0.0, 1.0) = 0.5;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float motion_blur : hint_range(0.0, 2.0) = 0.0;
uniform float shutter : hint_range(0.0, 360.0) = 180.0;

vec4 bg_fill() {
	float w = clamp(min(progress, 1.0 - progress) * 25.0, 0.0, 1.0);
	return vec4(background.rgb * background.a, background.a) * w;
}

vec4 face(vec2 uv, float angle, bool use_from, float half_w, vec3 axis_sign, float back, out float dist) {
	vec3 rot = axis_sign * angle;
	vec3 pivot = vec3(0.0, 0.0, half_w);
	vec4 hit = tr_card(uv, rot, pivot, vec3(0.0, 0.0, back), vec2(tr_ratio(), 1.0), depth);
	dist = hit.w;
	if (hit.w < 0.0 || hit.z < 0.0) {
		dist = -1.0;
		return vec4(0.0);
	}
	vec4 c = use_from ? texture(from_tex, hit.xy) : texture(to_tex, hit.xy);
	float light = mix(1.0, tr_card_light(rot, vec3(0.0, 0.0, 1.0)), shading);
	return tr_shade(c, light);
}

vec4 scene(vec2 uv, float pr) {
	float p = tr_ease(pr, 3);
	bool sideways = direction < 2;
	float sign_dir = (direction == 0 || direction == 2) ? 1.0 : -1.0;
	float half_w = sideways ? tr_ratio() * 0.5 : 0.5;
	vec3 axis = sideways ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	float back = sin(p * TR_PI) * pull_back * half_w * 2.0;
	float a_from = -90.0 * p * sign_dir;
	float a_to = 90.0 * (1.0 - p) * sign_dir;
	if (!sideways) {
		a_from = -a_from;
		a_to = -a_to;
	}
	float d_from;
	float d_to;
	vec4 cf = face(uv, a_from, true, half_w, axis, back, d_from);
	vec4 ct = face(uv, a_to, false, half_w, axis, back, d_to);
	vec4 top = vec4(0.0);
	vec4 under = vec4(0.0);
	if (d_from >= 0.0 && d_to >= 0.0) {
		top = d_from < d_to ? cf : ct;
		under = d_from < d_to ? ct : cf;
	} else if (d_from >= 0.0) {
		top = cf;
	} else if (d_to >= 0.0) {
		top = ct;
	}
	return tr_over(top, tr_over(under, bg_fill()));
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
	for (int i = 0; i < 40; i++) {
		acc += scene(uv, progress + w * ((float(i) + j) / 40.0 - 0.5));
	}
	return acc / 40.0;
}

void fragment() {
	COLOR = transition(UV);
}
