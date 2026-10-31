shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float sway : hint_range(0.0, 30.0) = 9.0;
uniform float pull_back : hint_range(0.0, 0.6) = 0.22;
uniform float gap : hint_range(0.0, 0.6) = 0.2;
uniform vec4 line_colour : source_color = vec4(0.85, 0.85, 0.82, 1.0);
uniform vec4 peg_colour : source_color = vec4(0.78, 0.6, 0.38, 1.0);
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec4 hang(vec2 w, float cx, float theta, bool use_from, bool mirror) {
	vec2 pivot = vec2(cx, 0.5);
	vec2 local = tr_rotate(w - pivot, -theta) + vec2(0.0, 0.5);
	vec2 cuv = tr_frame_uv(local);
	if (mirror) {
		cuv.x = 1.0 - cuv.x;
	}
	vec4 c = use_from ? from_at(cuv) : to_at(cuv);
	vec2 pl = local - vec2(0.0, 0.5);
	float peg = step(abs(pl.x), 0.022) * step(abs(pl.y + 0.015), 0.05);
	vec4 pc = vec4(peg_colour.rgb * peg_colour.a, peg_colour.a);
	return mix(c, pc, peg * smoothstep(0.0, 0.08, min(progress, 1.0 - progress)));
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float e = tr_ease(p, 3);
	float k = 1.0 - pull_back * sin(TR_PI * e);
	vec2 w = tr_world(uv) / k;
	bool mirror = direction == 1;
	if (mirror) {
		w.x = -w.x;
	}
	float pitch = tr_ratio() + gap;
	float theta = radians(sway) * sin(2.0 * TR_PI * p) * pow(1.0 - p, 1.5) * 1.6;
	float lag = radians(sway) * 0.35 * sin(2.6 * TR_PI * p) * pow(1.0 - p, 1.2);
	vec4 cf = hang(w, -e * pitch, theta, true, mirror);
	vec4 ct = hang(w, (1.0 - e) * pitch, theta + lag, false, mirror);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	float lw = 0.004 / k;
	float line = (1.0 - smoothstep(lw * 0.5, lw * 1.5, abs(w.y - 0.505))) * sin(TR_PI * e);
	vec4 lc = vec4(line_colour.rgb * line_colour.a, line_colour.a) * line;
	vec4 res = tr_over(ct, tr_over(cf, tr_over(lc, bg)));
	res = mix(res, from_at(uv), 1.0 - smoothstep(0.0, 0.03, progress));
	return mix(res, to_at(uv), smoothstep(0.97, 1.0, progress));
}

void fragment() {
	COLOR = transition(UV);
}
