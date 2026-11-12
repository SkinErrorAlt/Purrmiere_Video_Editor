shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float crystal : hint_range(0.3, 3.0) = 1.0;
uniform vec4 rime : source_color = vec4(0.84, 0.92, 1.0, 1.0);
uniform float refraction : hint_range(0.0, 1.0) = 0.5;
uniform float sparkle : hint_range(0.0, 1.0) = 0.5;
uniform float balance : hint_range(0.3, 0.7) = 0.5;
uniform float softness : hint_range(0.0, 1.0) = 0.4;

float frost_field(vec2 uv) {
	vec2 a = vec2(uv.x * tr_ratio(), uv.y);
	float big = tr_fbm(a * (6.0 * crystal) + seed * 3.1);
	float fine = tr_fbm(a * (17.0 * crystal) + 4.0 + seed);
	return big * 0.7 + fine * 0.3;
}

float frost_cov(vec2 uv, float grow) {
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float f = frost_field(uv);
	float d = edge - (f - 0.4) * 0.5;
	float front = grow * 0.62;
	float soft = 0.02 + softness * 0.12;
	return clamp(smoothstep(front + soft, front - soft, d), 0.0, 1.0);
}

vec2 frost_refract(vec2 uv) {
	float e = 0.0032;
	vec2 a = vec2(uv.x * tr_ratio(), uv.y);
	float h = tr_fbm(a * (13.0 * crystal) + seed);
	float hx = tr_fbm((a + vec2(e, 0.0)) * (13.0 * crystal) + seed);
	float hy = tr_fbm((a + vec2(0.0, e)) * (13.0 * crystal) + seed);
	return vec2(hx - h, hy - h) / e * 0.0016;
}

float frost_sparkle(vec2 uv) {
	vec2 g = vec2(uv.x * tr_ratio(), uv.y) * 150.0;
	vec2 id = floor(g);
	vec2 f = fract(g);
	vec2 r = tr_hash2(id + floor(seed) + 0.5);
	if (r.x < 0.93) {
		return 0.0;
	}
	vec2 c = vec2(0.3) + 0.4 * tr_hash2(id + 1.7);
	float d = length(f - c);
	return smoothstep(0.22, 0.0, d) * (0.5 + 0.5 * r.y);
}

void fragment() {
	vec2 uv = UV;
	float p = progress;
	float bl = clamp(balance, 0.3, 0.7);
	float grow = p < bl ? p / bl : 1.0 - (p - bl) / max(1.0 - bl, 0.0001);
	grow = clamp(grow, 0.0, 1.0);

	float cov = frost_cov(uv, grow);
	float swap = smoothstep(bl - 0.05, bl + 0.05, p);
	vec2 refr = frost_refract(uv) * cov * (0.4 + refraction * 1.8);
	vec4 img = mix(from_clamped(uv + refr), to_clamped(uv + refr), swap);

	float veins = frost_field(uv);
	float ridge = 1.0 - abs(veins * 2.0 - 1.0);
	float vein_light = 0.55 + 0.7 * smoothstep(0.5, 0.9, veins) + 0.5 * smoothstep(0.6, 1.0, ridge);
	vec3 ice = mix(img.rgb * 0.5 + vec3(0.1), rime.rgb * vein_light, 0.82);
	float spk = frost_sparkle(uv) * sparkle * cov;
	ice += vec3(spk) * 1.4;

	vec3 col = mix(img.rgb, ice, cov);
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
