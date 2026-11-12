shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float strength : hint_range(0.0, 1.0) = 0.8;
uniform float texture_keep : hint_range(0.0, 1.5) = 0.6;
uniform float heal : hint_range(0.0, 1.0) = 0.4;
uniform float heal_threshold : hint_range(0.02, 0.3) = 0.08;
uniform bool skin_only = false;
uniform float skin_tolerance : hint_range(0.0, 1.0) = 0.5;
uniform int show = 0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 unpm(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

float skin_weight(vec3 c) {
	float l = dot(c, LUMA);
	float warm = clamp((c.r - c.b) * 3.0, 0.0, 1.0);
	float ord = clamp((c.r - c.g) * 6.0 + 0.35, 0.0, 1.0) * clamp((c.g - c.b) * 6.0 + 0.35, 0.0, 1.0);
	float lum = smoothstep(0.12, 0.28, l) * (1.0 - smoothstep(0.85, 1.0, l));
	return clamp(warm * ord * lum, 0.0, 1.0);
}

void fragment() {
	vec4 srcp = texture(effect_tex, UV);
	float a = srcp.a;
	vec3 src = unpm(srcp);
	vec3 low = unpm(texture(TEXTURE, UV));
	vec3 high = src - low;

	float mag = max(max(abs(high.r), abs(high.g)), abs(high.b));
	float t0 = max(heal_threshold, 0.001);
	float spike = smoothstep(t0, t0 * 2.5, mag);
	vec3 hf = high * (1.0 - heal * spike);
	hf *= texture_keep;

	vec3 retouched = clamp(low + hf, 0.0, 1.0);

	float m = 1.0;
	if (skin_only) {
		m = clamp(skin_weight(src) + (1.0 - clamp(skin_tolerance, 0.0, 1.0)), 0.0, 1.0);
	}
	vec3 outc = mix(src, retouched, clamp(strength, 0.0, 1.0) * m);

	if (show == 1) {
		outc = low;
	} else if (show == 2) {
		outc = clamp(high * 2.0 + 0.5, 0.0, 1.0);
	}

	COLOR = vec4(outc * a, a);
}
