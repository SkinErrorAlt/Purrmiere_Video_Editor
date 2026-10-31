shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int origin = 0;
uniform vec4 colour : source_color = vec4(1.0, 0.42, 0.05, 1.0);
uniform float scale : hint_range(0.2, 4.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.6;
uniform float scorch : hint_range(0.0, 1.0) = 0.6;

float distance_field(vec2 uv) {
	vec2 q = tr_world(uv);
	if (origin == 1) {
		return 1.0 - uv.x;
	} else if (origin == 2) {
		return uv.y;
	} else if (origin == 3) {
		return 1.0 - uv.y;
	} else if (origin == 4) {
		return length(q) / (0.5 * sqrt(tr_ratio() * tr_ratio() + 1.0));
	} else if (origin == 5) {
		return length(uv) / 1.41421356;
	}
	return uv.x;
}

vec3 fire_ramp(float h) {
	vec3 ember = vec3(0.55, 0.06, 0.0);
	vec3 flame = colour.rgb;
	vec3 gold = vec3(1.0, 0.86, 0.38);
	vec3 white = vec3(1.0, 0.99, 0.94);
	vec3 c = mix(ember, flame, smoothstep(0.1, 0.4, h));
	c = mix(c, gold, smoothstep(0.4, 0.72, h));
	return mix(c, white, smoothstep(0.72, 1.0, h));
}

vec4 transition(vec2 uv) {
	float p = progress;
	vec4 base = mix(from_at(uv), to_at(uv), smoothstep(0.42, 0.58, p));
	float b = sin(TR_PI * clamp(p, 0.0, 1.0));
	if (b <= 0.0) {
		return base;
	}
	vec2 q = tr_world(uv);
	float n = tr_fbm(q * 3.0 / scale + vec2(0.0, p * 1.2));
	float field = distance_field(uv) * 0.75 + (n - 0.5) * 0.6 * roughness + 0.12;
	float front = b * b * b * 2.05 - 0.4;
	float h = clamp((front - field) / 0.45, 0.0, 1.0);
	float edge = clamp((front + 0.18 - field) / 0.18, 0.0, 1.0) * (1.0 - smoothstep(0.0, 0.35, h));
	vec3 fire = fire_ramp(h) * smoothstep(0.0, 0.2, h);
	float glow = smoothstep(0.0, 0.25, h);
	vec3 dark = base.rgb * (1.0 - edge * scorch * 0.7);
	dark = mix(dark, dark * vec3(1.0, 0.55, 0.3), edge * scorch * base.a);
	vec3 rgb = dark + fire * (1.0 - dark * 0.6);
	float a = max(base.a, glow);
	rgb = mix(rgb, fire_ramp(h), smoothstep(0.7, 1.0, h));
	a = mix(a, 1.0, smoothstep(0.7, 1.0, h));
	return vec4(clamp(rgb, vec3(0.0), vec3(a)), a);
}

void fragment() {
	COLOR = transition(UV);
}
