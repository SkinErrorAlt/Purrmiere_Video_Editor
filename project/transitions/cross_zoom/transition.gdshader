shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float strength : hint_range(0.0, 1.0) = 0.4;
uniform bool travel = true;
uniform vec2 centre = vec2(0.5, 0.5);

const int SAMPLES = 32;

float expo_in_out(float t) {
	if (t <= 0.0) {
		return 0.0;
	}
	if (t >= 1.0) {
		return 1.0;
	}
	return t < 0.5 ? 0.5 * pow(2.0, 20.0 * t - 10.0) : 1.0 - 0.5 * pow(2.0, 10.0 - 20.0 * t);
}

float dither(vec2 uv) {
	vec2 px = floor(uv * frame_px);
	return fract(52.9829189 * fract(dot(px, vec2(0.06711056, 0.00583715))));
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float mixer = expo_in_out(p);
	float s = max(strength * sin(TR_PI * p), 0.0);
	if (s < 0.00001) {
		return mix(texture(from_tex, uv), texture(to_tex, uv), mixer);
	}
	vec2 c = travel ? vec2(mix(centre.x - 0.25, centre.x + 0.25, mixer), centre.y) : centre;
	vec2 toward = c - uv;
	float j = dither(uv);
	vec4 acc = vec4(0.0);
	float total = 0.0;
	for (int i = 0; i < SAMPLES; i++) {
		float f = (float(i) + j) / float(SAMPLES);
		float w = 4.0 * (f - f * f) + 0.02;
		vec2 suv = uv + toward * f * s;
		acc += mix(from_clamped(suv), to_clamped(suv), mixer) * w;
		total += w;
	}
	return acc / total;
}

void fragment() {
	COLOR = transition(UV);
}
