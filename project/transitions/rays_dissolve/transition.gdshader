shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform vec2 centre = vec2(0.5, 0.35);
uniform float length : hint_range(0.0, 1.0) = 0.7;
uniform float threshold : hint_range(0.0, 1.0) = 0.5;
uniform float intensity : hint_range(0.0, 4.0) = 1.6;
uniform vec4 tint : source_color = vec4(1.0, 0.96, 0.88, 1.0);
uniform float decay : hint_range(0.0, 1.0) = 0.6;

const int TAPS = 72;

vec3 to_linear(vec3 c) {
	vec3 lo = c / 12.92;
	vec3 hi = pow((max(c, vec3(0.0)) + 0.055) / 1.055, vec3(2.4));
	return mix(lo, hi, step(vec3(0.04045), c));
}

vec3 to_srgb(vec3 c) {
	vec3 lo = c * 12.92;
	vec3 hi = 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055;
	return mix(lo, hi, step(vec3(0.0031308), c));
}

vec3 fast_linear(vec3 c) {
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);
}

vec4 lin_premul(vec4 c) {
	if (c.a <= 0.0) {
		return vec4(0.0);
	}
	return vec4(to_linear(c.rgb / c.a) * c.a, c.a);
}

vec4 srgb_premul(vec4 c) {
	if (c.a <= 0.0) {
		return vec4(0.0);
	}
	return vec4(to_srgb(c.rgb / c.a) * c.a, c.a);
}

vec3 bright_part(vec3 c, float t) {
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	float knee = max(t * 0.5, 0.002);
	float soft = clamp(l - t + knee, 0.0, 2.0 * knee);
	soft = soft * soft / (4.0 * knee);
	return c * max(soft, l - t) / max(l, 0.00001);
}

vec3 source_at(vec2 uv, float w, bool need_from, bool need_to, float t) {
	if (!tr_inside(uv)) {
		return vec3(0.0);
	}
	vec3 c = vec3(0.0);
	if (need_from) {
		c += fast_linear(texture(from_tex, uv).rgb) * (1.0 - w);
	}
	if (need_to) {
		c += fast_linear(texture(to_tex, uv).rgb) * w;
	}
	return bright_part(c, t);
}

float dither(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float k = clamp((p - 0.35) / 0.3, 0.0, 1.0);
	float w = k * k * (3.0 - 2.0 * k);
	float sn = sin(TR_PI * p);
	float e = sn * sn;
	vec4 a = from_at(uv);
	vec4 b = to_at(uv);
	if (e <= 0.0 || intensity <= 0.0 || length <= 0.0) {
		return mix(a, b, w);
	}
	vec4 base = mix(lin_premul(a), lin_premul(b), w);
	bool need_from = w < 1.0;
	bool need_to = w > 0.0;
	float t = to_linear(vec3(threshold)).x;
	float reach = length * (0.3 + 0.7 * e);
	vec2 span = (centre - uv) * reach;
	float jit = dither(uv * frame_px);
	float fade_rate = mix(0.2, 5.0, decay);
	vec3 acc = vec3(0.0);
	float total = 0.0;
	for (int i = 0; i < TAPS; i++) {
		float s = (float(i) + jit) / float(TAPS);
		float g = exp(-fade_rate * s);
		acc += source_at(uv + span * s, w, need_from, need_to, t) * g;
		total += g;
	}
	vec3 light = acc / total * 4.2 * to_linear(tint.rgb) * intensity * e;
	vec3 lit = base.rgb + (vec3(1.0) - min(base.rgb, vec3(1.0))) * (vec3(1.0) - exp(-light));
	float alpha = clamp(max(base.a, max(lit.r, max(lit.g, lit.b))), 0.0, 1.0);
	return srgb_premul(vec4(min(lit, vec3(alpha)), alpha));
}

void fragment() {
	COLOR = transition(UV);
}
