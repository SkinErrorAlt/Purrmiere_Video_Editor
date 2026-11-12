shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform vec2 centre = vec2(0.5, 0.5);
uniform float swirl : hint_range(0.0, 4.0) = 1.0;
uniform float streak : hint_range(0.0, 1.0) = 0.55;
uniform float spring : hint_range(0.0, 0.6) = 0.18;
uniform vec4 backdrop : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec4 warped(bool use_from, vec2 uv, float scale, float turn) {
	vec2 ar = vec2(tr_ratio(), 1.0);
	vec2 d = (uv - centre) * ar;
	float r = length(d);
	float ang = atan(d.y, d.x) - turn * exp(-r * 1.6);
	float sr = r / max(scale, 0.00001);
	vec2 src = centre + vec2(cos(ang), sin(ang)) * sr / ar;
	if (src.x < 0.0 || src.x > 1.0 || src.y < 0.0 || src.y > 1.0) {
		return vec4(0.0);
	}
	return use_from ? texture(from_tex, src) : texture(to_tex, src);
}

vec4 smeared(bool use_from, vec2 uv, float scale, float turn, float amount) {
	vec4 acc = vec4(0.0);
	float total = 0.0;
	for (int i = 0; i < 7; i++) {
		float f = float(i) / 6.0;
		float s = scale * (1.0 + amount * f * 0.65);
		float w = 1.0 - f * 0.7;
		acc += warped(use_from, uv, s, turn * (1.0 - f * 0.4)) * w;
		total += w;
	}
	return acc / max(total, 0.0001);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	vec4 bg = backdrop;
	if (p < 0.5) {
		float t = p * 2.0;
		float scale = pow(1.0 - t, 1.7);
		if (scale < 0.0008) {
			return bg;
		}
		vec4 c = smeared(true, uv, scale, swirl * t * 3.0, streak * t);
		return mix(bg, c, clamp(c.a, 0.0, 1.0));
	}
	float t2 = (p - 0.5) * 2.0;
	float over = 1.0 + spring * sin(t2 * TR_PI) * (1.0 - t2 * 0.5);
	float scale2 = pow(t2, 0.75) * over;
	if (scale2 < 0.0008) {
		return bg;
	}
	vec4 c2 = smeared(false, uv, scale2, -swirl * (1.0 - t2) * 3.0, streak * (1.0 - t2));
	return mix(bg, c2, clamp(c2.a, 0.0, 1.0));
}

void fragment() {
	COLOR = transition(UV);
}
