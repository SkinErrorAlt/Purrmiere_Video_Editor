shader_type canvas_item;
render_mode blend_disabled;

#include "res://engine/sound.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D mid_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform vec2 centre = vec2(0.5, 0.45);
uniform float size : hint_range(0.05, 1.5) = 0.42;
uniform float stretch : hint_range(0.25, 4.0) = 0.8;
uniform float feather : hint_range(0.0, 1.0) = 0.5;
uniform float blur : hint_range(0.0, 1.0) = 0.85;
uniform float push_in : hint_range(0.0, 15.0) = 3.0;
uniform float linger : hint_range(0.0, 1.0) = 0.35;
uniform float dim : hint_range(0.0, 1.0) = 0.15;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 unpm(vec4 c) {
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
}

void fragment() {
	vec2 full = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float f = clamp(mix(snd_voice, max(snd_voice, snd_voice_slow), linger), 0.0, 1.0);
	f = f * f * (3.0 - 2.0 * f);
	float z = 1.0 + push_in * 0.01 * f;
	vec2 uv = centre + (UV - centre) / z;
	vec4 s4 = texture(effect_tex, uv);
	float a = s4.a;
	vec3 sharp = unpm(s4);
	vec3 mid = unpm(texture(mid_tex, uv));
	vec3 heavy = unpm(texture(TEXTURE, uv));
	vec2 d = (uv - centre) * full;
	float r = max(size, 0.001) * full.y * 0.5;
	float e = length(d / vec2(r * max(stretch, 0.05), r));
	float fw = max(feather * 1.2, 0.01);
	float outside = smoothstep(1.0, 1.0 + fw, e) * f;
	float b = blur * outside;
	vec3 soft = b < 0.5 ? mix(sharp, mid, b * 2.0) : mix(mid, heavy, (b - 0.5) * 2.0);
	float hl = max(dot(soft, LUMA) - 0.7, 0.0);
	soft += soft * hl * 0.6 * outside;
	soft *= 1.0 - dim * outside;
	COLOR = vec4(clamp(soft, 0.0, 1.0) * a, a);
}
