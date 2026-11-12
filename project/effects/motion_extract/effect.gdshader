shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform float delay : hint_range(0.03, 1.0) = 0.1;
uniform int kind = 0;
uniform float gain : hint_range(1.0, 12.0) = 3.0;
uniform float grain : hint_range(0.0, 0.2) = 0.02;
uniform float keep : hint_range(0.0, 1.0) = 0.0;

vec3 unpremul(vec4 c) {
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
}

vec3 soft_gate(vec3 d) {
	vec3 m = abs(d);
	vec3 k = m * m / (m + grain + 1e-5);
	return sign(d) * k;
}

void fragment() {
	vec4 now = texture(TEXTURE, UV);
	float age = clamp(delay * history_fps, 1.0, max(float(history_count), 1.0));
	vec4 past = history_between(age, UV, now);
	vec3 a = unpremul(now);
	vec3 b = unpremul(past);
	vec3 d = soft_gate(a - b);
	vec3 rgb;
	if (kind == 1) {
		vec3 m = abs(d) * gain;
		float e = max(max(m.r, m.g), m.b);
		vec3 hue = a * e / max(max(max(a.r, a.g), a.b), 0.08);
		rgb = 1.0 - exp(-(hue + 0.25 * m) * 1.6);
	} else if (kind == 2) {
		rgb = clamp(vec3(0.5) + 0.5 * d * gain, 0.0, 1.0);
	} else {
		float l = dot(d, vec3(0.2126, 0.7152, 0.0722));
		vec3 tint = d - vec3(l);
		rgb = clamp(vec3(0.5 + 0.5 * l * gain) + 0.5 * tint * gain * 0.35, 0.0, 1.0);
	}
	rgb = mix(rgb, mix(rgb, a, 0.5) + (rgb - 0.5) * 0.5, keep);
	rgb = clamp(rgb, 0.0, 1.0);
	COLOR = vec4(rgb * now.a, now.a);
}
