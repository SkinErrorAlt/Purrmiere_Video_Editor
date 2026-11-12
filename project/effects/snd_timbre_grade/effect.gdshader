shader_type canvas_item;
render_mode blend_disabled;

#include "res://engine/sound.gdshaderinc"

uniform float strength : hint_range(0.0, 1.0) = 0.75;
uniform vec4 deep_colour : source_color = vec4(1.0, 0.42, 0.12, 1.0);
uniform vec4 bright_colour : source_color = vec4(0.32, 0.66, 1.0, 1.0);
uniform float follow : hint_range(0.0, 1.0) = 0.8;
uniform float contrast : hint_range(0.0, 1.0) = 0.35;
uniform float balance : hint_range(0.0, 1.0) = 0.45;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 push(vec3 rgb, vec3 tone, float k) {
	float y = dot(rgb, LUMA);
	vec3 t = tone - vec3(dot(tone, LUMA));
	vec3 o = rgb + t * k;
	return o + (y - dot(o, LUMA));
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float a = src.a;
	vec3 rgb = a > 0.0001 ? src.rgb / a : vec3(0.0);
	float loud = smoothstep(0.02, 0.2, snd_level) * mix(1.0, smoothstep(0.08, 0.8, snd_level), follow);
	float b = clamp((snd_bright - balance) * 2.2 + 0.5, 0.0, 1.0);
	float k = strength * loud;
	float y = dot(rgb, LUMA);
	float wd = pow(1.0 - y, 1.3) * (1.0 - b);
	float wb = pow(y, 1.2) * b;
	rgb = push(rgb, deep_colour.rgb, k * 0.9 * wd);
	rgb = push(rgb, bright_colour.rgb, k * 0.9 * wb);
	float deep_c = k * contrast * (1.0 - b);
	float y2 = dot(rgb, LUMA);
	rgb *= pow(max(y2, 0.0001), 0.35 * deep_c);
	float lift = k * contrast * b * 0.18;
	rgb = rgb * (1.0 - lift) + lift * mix(vec3(y2), bright_colour.rgb, 0.3);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
