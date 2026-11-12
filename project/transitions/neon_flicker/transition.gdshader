shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float stutter : hint_range(0.0, 1.0) = 0.7;
uniform float bloom : hint_range(0.0, 1.0) = 0.6;
uniform vec4 gas : source_color = vec4(0.45, 0.85, 1.0, 1.0);
uniform float gas_amount : hint_range(0.0, 1.0) = 0.45;
uniform float strike : hint_range(0.0, 2.0) = 0.9;
uniform float floor_level : hint_range(0.0, 0.4) = 0.04;

float pulse_train(float t, float salt) {
	float step_i = floor(t * 26.0);
	float h = tr_hash(vec2(step_i, salt));
	float h2 = tr_hash(vec2(step_i + 0.5, salt + 3.0));
	return h * 0.75 + h2 * 0.25;
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	bool first = p < 0.5;
	float t = first ? p * 2.0 : (p - 0.5) * 2.0;
	float health = first ? 1.0 - t : t;
	float noise = pulse_train(p, 11.0);
	float threshold = (1.0 - health) * (0.55 + 0.45 * clamp(stutter, 0.0, 1.0));
	float on = noise > threshold ? 1.0 : 0.0;
	float level = mix(1.0, on * mix(0.35, 1.0, health), clamp(stutter, 0.0, 1.0));
	level = mix(level, health, 0.25);
	if (p <= 0.002) {
		level = 1.0;
	}
	if (p >= 0.998) {
		level = 1.0;
	}
	vec4 src = first ? from_at(uv) : to_at(uv);
	vec3 base = src.rgb;
	float lum = dot(base, vec3(0.2126, 0.7152, 0.0722));
	vec4 soft = first ? from_lod(uv, 3.0) : to_lod(uv, 3.0);
	float soft_lum = dot(soft.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 glow = mix(soft.rgb, gas.rgb * soft_lum, clamp(gas_amount, 0.0, 1.0)) * bloom * (1.0 - health) * 1.4;
	vec3 lit = base * level + glow * level;
	float flash = exp(-pow((p - 0.5) * 26.0, 2.0)) * strike;
	lit += gas.rgb * flash * (0.4 + 0.6 * lum);
	vec3 dark = mix(vec3(clamp(floor_level, 0.0, 0.4)), lit, clamp(level + 0.12, 0.0, 1.0));
	return vec4(mix(dark, base, clamp(level, 0.0, 1.0) * clamp(level, 0.0, 1.0)), 1.0);
}

void fragment() {
	COLOR = transition(UV);
}
