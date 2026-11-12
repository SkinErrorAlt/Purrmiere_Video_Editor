shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1920.0, 1080.0);
uniform float speed : hint_range(0.2, 3.0) = 1.1;
uniform float strength : hint_range(0.0, 2.0) = 1.3;
uniform float ring_width : hint_range(0.01, 0.3) = 0.07;
uniform float wave_length : hint_range(0.2, 1.9) = 1.0;
uniform float heat : hint_range(0.0, 1.0) = 0.5;
uniform float colour_split : hint_range(0.0, 1.0) = 0.3;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec3 unpm(vec4 c) {
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
}

void fragment() {
	vec4 src = texture(effect_tex, UV);
	vec4 b0 = texelFetch(TEXTURE, ivec2(0, 0), 0);
	float s = floor(b0.r * 63.0 + 0.5);
	float fps = max(history_fps, 1.0);
	float span = min(wave_length * fps, 58.0);
	if (b0.r > 0.995 || s > span || strength <= 0.0) {
		COLOR = src;
	} else {
		float a = max(src.a, 0.0001);
		float asp = tex_size.x / max(tex_size.y, 1.0);
		vec2 c = b0.ba;
		float k = b0.g * strength;
		float t = (s + 0.5) / fps;
		float u = s / span;
		vec2 d = vec2((UV.x - c.x) * asp, UV.y - c.y);
		float dist = length(d);
		vec2 dir = dist > 1e-5 ? d / dist : vec2(0.0);
		float r = speed * t * (1.0 - 0.25 * u);
		float w = ring_width * (1.0 + 1.5 * r);
		float x = (dist - r) / w;
		float fade = pow(1.0 - u, 1.5) / (1.0 + 1.2 * r);
		float bend = x * exp(-x * x) * 0.05 * k * fade * w / 0.07;
		vec2 off = -dir * bend;
		float inside = smoothstep(0.0, -1.5, x) * heat * k * exp(-t * 1.8);
		vec2 hp = UV * vec2(asp, 1.0) * 26.0;
		vec2 haze = (vec2(vnoise(hp + vec2(0.0, t * 9.0)), vnoise(hp + vec2(31.0, -t * 7.0))) - 0.5) * 0.006 * inside;
		vec2 q = UV + (off + haze) / vec2(asp, 1.0);
		float split = colour_split * abs(bend) * 0.5;
		vec3 col;
		col.r = unpm(texture(effect_tex, q - dir / vec2(asp, 1.0) * split)).r;
		col.g = unpm(texture(effect_tex, q)).g;
		col.b = unpm(texture(effect_tex, q + dir / vec2(asp, 1.0) * split)).b;
		float lift = (exp(-pow((x - 0.35) / 0.45, 2.0)) * 0.22 - exp(-pow((x + 0.9) / 0.6, 2.0)) * 0.08) * k * fade;
		vec3 l = col * col;
		l *= 1.0 + lift;
		l += vec3(1.0, 0.9, 0.75) * 0.35 * k * exp(-t * 14.0) * exp(-dist * dist / 0.02);
		COLOR = vec4(sqrt(clamp(l, 0.0, 1.0)) * a, a);
	}
}
