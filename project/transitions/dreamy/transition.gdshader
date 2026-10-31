shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float waves : hint_range(1.0, 20.0) = 5.0;
uniform float wave_height : hint_range(0.0, 0.1) = 0.03;
uniform float glow : hint_range(0.0, 1.0) = 0.5;
uniform float glow_size : hint_range(2.0, 80.0) = 24.0;

vec2 wave_shift(vec2 uv, float amount, float phase) {
	float y = amount * wave_height * cos(TR_PI * 2.0 * waves * uv.x + phase);
	return uv + vec2(0.0, y);
}

vec4 dream_at(vec2 uv, float p) {
	vec4 f = from_clamped(wave_shift(uv, p, p * 6.0));
	vec4 t = to_clamped(wave_shift(uv, 1.0 - p, TR_PI + (1.0 - p) * 6.0));
	vec4 inside = tr_inside(uv) ? vec4(1.0) : vec4(0.0);
	return mix(f, t, smoothstep(0.0, 1.0, p)) * inside;
}

vec4 transition(vec2 uv) {
	float p = progress;
	vec4 base = dream_at(uv, p);
	float env = sin(TR_PI * p);
	env *= env;
	if (glow <= 0.0 || env <= 0.0001) {
		return base;
	}
	vec2 r = glow_size * px_scale / frame_px;
	vec4 acc = vec4(0.0);
	for (int i = 0; i < 12; i++) {
		float a = float(i) * TR_PI / 6.0 + 0.3;
		float rr = (i % 2 == 0) ? 1.0 : 0.55;
		acc += dream_at(uv + vec2(cos(a), sin(a)) * r * rr, p);
	}
	acc /= 12.0;
	float k = glow * env;
	vec3 lit = base.rgb + acc.rgb * k * (vec3(1.0) - base.rgb) + vec3(0.06) * k * base.a;
	float a = max(base.a, acc.a * k);
	return vec4(min(lit, vec3(a)), a);
}

void fragment() {
	COLOR = transition(UV);
}
