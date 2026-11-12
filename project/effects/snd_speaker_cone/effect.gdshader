shader_type canvas_item;
render_mode blend_disabled;

#include "res://engine/sound.gdshaderinc"

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float push : hint_range(0.0, 120.0) = 36.0;
uniform float travel : hint_range(0.05, 2.0) = 0.4;
uniform vec2 centre = vec2(0.5, 0.5);
uniform int follow = 0;
uniform float light : hint_range(0.0, 1.0) = 0.5;
uniform float light_angle : hint_range(-180.0, 180.0) = -50.0;
uniform float damping : hint_range(0.0, 1.0) = 0.45;

float pick(vec4 v) {
	if (follow == 1) {
		return v.r;
	}
	if (follow == 2) {
		return v.b;
	}
	return v.g;
}

float height(float r, float avg) {
	return (pick(snd_past(r)) - avg) * pow(1.0 - clamp(r, 0.0, 1.0), damping * 1.6);
}

void fragment() {
	vec2 asp = vec2(tex_size.x / max(tex_size.y, 1.0), 1.0);
	vec2 d = (UV - centre) * asp;
	vec2 far = max(abs(vec2(0.0) - centre), abs(vec2(1.0) - centre)) * asp;
	float rmax = max(length(far), 0.001);
	float r = length(d) / rmax;
	vec2 dir = length(d) > 1e-5 ? normalize(d) : vec2(0.0);
	float avg = 0.0;
	for (int i = 0; i < 16; i++) {
		avg += pick(snd_past((float(i) + 0.5) / 16.0));
	}
	avg /= 16.0;
	float dr = 1.0 / 64.0;
	float h = height(r, avg);
	float slope = (height(r + dr, avg) - height(max(r - dr, 0.0), avg)) / (2.0 * dr);
	float px = push * px_scale / max(tex_size.y, 1.0);
	vec2 off = dir * (h * px * 0.6 - slope * px * 0.12) / asp;
	vec4 src = texture(TEXTURE, clamp(UV - off, vec2(0.0), vec2(1.0)));
	float a = src.a;
	vec3 rgb = a > 0.0001 ? src.rgb / a : vec3(0.0);
	vec2 ld = vec2(cos(radians(light_angle)), sin(radians(light_angle)));
	float facing = dot(dir, ld);
	float shade = clamp(-slope * facing * 0.11 * light * push / 36.0, -0.35, 0.35);
	rgb = rgb * (1.0 + shade) + vec3(max(shade, 0.0) * 0.15);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
