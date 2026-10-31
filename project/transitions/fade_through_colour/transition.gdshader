shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform vec4 colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float hold : hint_range(0.0, 0.8) = 0.0;
uniform float balance : hint_range(0.1, 0.9) = 0.5;
uniform int curve = 0;
uniform float blur : hint_range(0.0, 200.0) = 0.0;

const int TAPS = 20;

float jitter(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

vec4 defocused(vec2 uv, bool use_to, float k) {
	float radius = blur * px_scale * pow(clamp(k, 0.0, 1.0), 0.6);
	if (radius < 0.01 || !tr_inside(uv)) {
		return use_to ? to_at(uv) : from_at(uv);
	}
	float spin = jitter(uv * frame_px) * TR_PI * 2.0;
	vec4 acc = vec4(0.0);
	float total = 0.0;
	for (int i = 0; i < TAPS; i++) {
		float fi = (float(i) + 0.5) / float(TAPS);
		float a = float(i) * 2.39996323 + spin;
		vec2 at = uv + vec2(cos(a), sin(a)) * sqrt(fi) * radius / frame_px;
		float g = exp(-1.5 * fi);
		acc += (use_to ? to_clamped(at) : from_clamped(at)) * g;
		total += g;
	}
	return acc / total;
}

vec4 transition(vec2 uv) {
	vec4 c = vec4(colour.rgb * colour.a, colour.a);
	int ek = curve == 1 ? 3 : 0;
	float t1 = balance * (1.0 - hold);
	float t2 = t1 + hold;
	if (progress < t2) {
		float k = tr_ease(progress / max(t1, 0.0001), ek);
		return mix(defocused(uv, false, k), c, k);
	}
	float k2 = tr_ease((progress - t2) / max(1.0 - t2, 0.0001), ek);
	return mix(c, defocused(uv, true, 1.0 - k2), k2);
}

void fragment() {
	COLOR = transition(UV);
}
