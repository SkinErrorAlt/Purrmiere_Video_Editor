shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D level_2 : filter_linear, repeat_disable;
uniform sampler2D level_3 : filter_linear, repeat_disable;
uniform sampler2D level_4 : filter_linear, repeat_disable;
uniform int mode : hint_range(0, 1) = 0;
uniform float strength : hint_range(0.0, 100.0) = 70.0;
uniform float brightness : hint_range(-100.0, 100.0) = 0.0;
uniform float contrast : hint_range(-100.0, 100.0) = 0.0;
uniform float glow : hint_range(0.0, 100.0) = 35.0;
uniform float drain : hint_range(0.0, 100.0) = 30.0;
uniform float dark_corners : hint_range(0.0, 100.0) = 0.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec4 cubic_sample(sampler2D tex, vec2 uv) {
	vec2 size = vec2(textureSize(tex, 0));
	vec2 p = uv * size - 0.5;
	vec2 f = fract(p);
	vec2 i = floor(p);
	vec2 f2 = f * f;
	vec2 f3 = f2 * f;
	vec2 w0 = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0;
	vec2 w1 = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
	vec2 w2 = (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0;
	vec2 w3 = f3 / 6.0;
	vec2 g0 = w0 + w1;
	vec2 g1 = w2 + w3;
	vec2 h0 = (i - 0.5 + w1 / g0) / size;
	vec2 h1 = (i + 1.5 + w3 / g1) / size;
	vec4 a = texture(tex, vec2(h0.x, h0.y));
	vec4 b = texture(tex, vec2(h1.x, h0.y));
	vec4 c = texture(tex, vec2(h0.x, h1.y));
	vec4 d = texture(tex, vec2(h1.x, h1.y));
	return g0.y * (g0.x * a + g1.x * b) + g1.y * (g0.x * c + g1.x * d);
}

vec3 high_key_tone(vec3 x) {
	float s = clamp(strength, 0.0, 100.0) / 100.0;
	float b = clamp(brightness, -100.0, 100.0) / 100.0;
	float lift = clamp(0.3 * s * (1.0 + 0.4 * b), 0.0, 0.6);
	float g = max(1.0 + s * (1.4 + 1.1 * b), 0.35);
	return lift + (1.0 - lift) * (1.0 - pow(max(1.0 - x, vec3(0.0)), vec3(g)));
}

float picture_peak() {
	float peak = 0.0;
	for (int j = 0; j < 7; j++) {
		for (int i = 0; i < 12; i++) {
			vec4 c = texture(level_4, (vec2(float(i), float(j)) + 0.5) / vec2(12.0, 7.0));
			vec3 rgb = c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
			peak = max(peak, dot(rgb, LUMA));
		}
	}
	return max(peak, 0.05);
}

float low_key_gain(float key, float pivot) {
	float s = clamp(strength, 0.0, 100.0) / 100.0;
	float depth = 3.4 * s;
	float u = 1.0 - smoothstep(0.0, pivot, key);
	return exp(-depth * u * u);
}

vec3 s_curve(vec3 y, float pivot) {
	float e = 1.0 + clamp(contrast, -100.0, 100.0) / 100.0 * 0.8;
	vec3 lo = pivot * pow(clamp(y / pivot, 0.0, 1.0), vec3(e));
	vec3 hi = 1.0 - (1.0 - pivot) * pow(clamp((1.0 - y) / (1.0 - pivot), 0.0, 1.0), vec3(e));
	return mix(hi, lo, step(y, vec3(pivot)));
}

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

void fragment() {
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	vec3 rgb = straight(c);
	vec3 halo = straight(cubic_sample(level_2, UV)) * 0.2 + straight(cubic_sample(level_3, UV)) * 0.35 + straight(cubic_sample(level_4, UV)) * 0.45;
	float g = clamp(glow, 0.0, 100.0) / 100.0;
	vec3 outc;
	if (mode == 0) {
		float lift = clamp(0.85 / picture_peak(), 1.0, 2.5);
		outc = s_curve(high_key_tone(clamp(rgb * lift, 0.0, 1.0)), 0.7);
		outc = 1.0 - (1.0 - outc) * (1.0 - clamp(halo * g * 0.9, 0.0, 1.0));
	} else {
		float b = clamp(brightness, -100.0, 100.0) / 100.0;
		float pivot = clamp(picture_peak() * (0.92 - 0.3 * b), 0.12, 0.98);
		float l = dot(rgb, LUMA);
		float light = dot(halo, LUMA);
		float keep = g * smoothstep(pivot * 0.25, pivot * 0.7, light);
		outc = rgb * mix(low_key_gain(l, pivot), 1.0, keep * 0.85);
		halo *= smoothstep(pivot * 0.5, pivot, light);
		outc = s_curve(outc, 0.35);
		outc = 1.0 - (1.0 - outc) * (1.0 - clamp(halo * g * 0.3, 0.0, 1.0));
	}
	float dl = dot(outc, LUMA);
	outc = mix(vec3(dl), outc, 1.0 - clamp(drain, 0.0, 100.0) / 100.0 * 0.85);
	vec2 frame = vec2(textureSize(effect_tex, 0));
	vec2 aspect = vec2(frame.x / max(frame.y, 1.0), 1.0);
	float d = length((UV - 0.5) * aspect) / length(0.5 * aspect);
	float corner = pow(smoothstep(0.3, 1.05, d), 1.4);
	outc *= 1.0 - clamp(dark_corners, 0.0, 100.0) / 100.0 * 0.85 * corner;
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
