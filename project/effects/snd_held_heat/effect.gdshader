shader_type canvas_item;
render_mode blend_disabled;

#include "res://engine/sound.gdshaderinc"

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float shimmer : hint_range(0.0, 40.0) = 15.0;
uniform float rise : hint_range(0.0, 3.0) = 0.9;
uniform float height_frac : hint_range(0.05, 1.0) = 0.8;
uniform float scale : hint_range(0.2, 4.0) = 1.0;
uniform float warmth : hint_range(0.0, 1.0) = 0.3;
uniform float threshold_sus : hint_range(0.0, 1.0) = 0.45;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec2 flow(vec2 p, float t) {
	vec2 q = vec2(p.x * 7.0, p.y * 2.6 + t * rise * 2.4);
	float n1 = snd_fbm(q);
	float n2 = snd_fbm(q * 1.9 + vec2(4.3, t * rise * 1.7));
	return vec2(n1 - 0.5, (n2 - 0.5) * 0.45);
}

void fragment() {
	vec2 asp = vec2(tex_size.x / max(tex_size.y, 1.0), 1.0);
	float heat = smoothstep(threshold_sus, 1.0, snd_sustain);
	heat = heat * heat * (3.0 - 2.0 * heat);
	vec2 p = UV * asp / max(scale, 0.05);
	float band = smoothstep(1.0 - height_frac, 1.0 - height_frac * 0.35, UV.y);
	float amt = heat * band;
	vec2 o = flow(p, clip_time) * shimmer * amt * px_scale / max(tex_size, vec2(1.0)) * 2.0;
	vec4 c0 = texture(TEXTURE, clamp(UV + o, vec2(0.0), vec2(1.0)));
	vec4 c1 = texture(TEXTURE, clamp(UV + o * 0.6 + vec2(0.0, 1.5 * px_scale / max(tex_size.y, 1.0)) * amt, vec2(0.0), vec2(1.0)));
	vec4 src = mix(c0, c1, 0.35 * amt);
	float a = src.a;
	vec3 rgb = a > 0.0001 ? src.rgb / a : vec3(0.0);
	float y = dot(rgb, LUMA);
	vec3 hot = rgb * vec3(1.06, 1.0, 0.9) + vec3(0.035, 0.018, 0.0);
	rgb = mix(rgb, hot, warmth * amt);
	rgb = mix(rgb, vec3(y) * 0.2 + rgb * 0.8 + vec3(0.02), 0.25 * warmth * amt);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
