shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float zoom : hint_range(0.4, 1.0) = 0.84;
uniform float corner_radius : hint_range(0.0, 0.5) = 0.18;
uniform float reel : hint_range(1.0, 4.0) = 2.4;
uniform float gap : hint_range(0.0, 0.5) = 0.12;
uniform float shadow : hint_range(0.0, 1.0) = 0.5;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

float round_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

vec4 frame_at(vec2 w, vec2 pivot, float angle, vec2 half_size, float r, float px, bool use_from, bool mirror, out float sd) {
	vec2 local = tr_rotate(w - pivot, -angle) + pivot;
	sd = round_box(local, half_size, r);
	vec2 cuv = tr_frame_uv(local);
	if (mirror) {
		cuv.x = 1.0 - cuv.x;
	}
	vec4 c = use_from ? from_at(cuv) : to_at(cuv);
	return c * (1.0 - smoothstep(-px, px, sd));
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float z_in = tr_ease(p / 0.28, 3);
	float z_out = tr_ease((p - 0.72) / 0.28, 3);
	float shrink = z_in - z_out;
	float s = mix(1.0, zoom, shrink);
	float r = corner_radius * 0.5 * shrink;
	float turn = tr_ease((p - 0.2) / 0.6, 3);
	vec2 w = tr_world(uv);
	bool mirror = direction == 1;
	if (mirror) {
		w.x = -w.x;
	}
	w /= s;
	vec2 half_size = vec2(tr_ratio() * 0.5, 0.5);
	vec2 pivot = vec2(0.0, -reel);
	float chord = half_size.x + gap * 0.5;
	float step_a = 2.0 * asin(clamp(chord / reel, 0.0, 1.0));
	float px = 1.5 / max(frame_px.y, 1.0) / s;
	float sd_f;
	float sd_t;
	vec4 cf = frame_at(w, pivot, step_a * turn, half_size, r, px, true, mirror, sd_f);
	vec4 ct = frame_at(w, pivot, step_a * (turn - 1.0), half_size, r, px, false, mirror, sd_t);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	float sh = shadow * shrink * (1.0 - smoothstep(-0.01, 0.06, min(sd_f, sd_t) - 0.015));
	bg = vec4(bg.rgb * (1.0 - 0.8 * sh), bg.a);
	vec4 res = tr_over(ct, tr_over(cf, bg));
	res = mix(res, from_at(uv), 1.0 - smoothstep(0.0, 0.03, progress));
	return mix(res, to_at(uv), smoothstep(0.97, 1.0, progress));
}

void fragment() {
	COLOR = transition(UV);
}
