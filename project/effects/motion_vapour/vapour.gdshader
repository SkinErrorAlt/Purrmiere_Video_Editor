shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/_motion_kit/kit.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D flow_tex : filter_nearest, repeat_disable;
uniform sampler2D global_tex : filter_nearest, repeat_disable;
uniform vec2 tex_size = vec2(2.0);
uniform float px_scale = 1.0;
uniform float time = 0.0;
uniform float life = 1.2;
uniform float rise = 1.6;
uniform float wind_angle = 0.0;
uniform float wind = 0.0;
uniform float swirl = 1.0;
uniform float swirl_size = 60.0;
uniform float drag = 0.5;
uniform float spread = 1.0;
uniform float sensitivity = 0.4;
uniform bool camera = true;
uniform float shake = 2.0;

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = kit_hash12(i);
	float b = kit_hash12(i + vec2(1.0, 0.0));
	float c = kit_hash12(i + vec2(0.0, 1.0));
	float d = kit_hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float potential(vec2 p, float t) {
	return vnoise(p + vec2(t * 0.13, -t * 0.07)) + 0.5 * vnoise(p * 2.03 + vec2(-t * 0.21, t * 0.17) + 7.3);
}

vec2 curl(vec2 p, float t) {
	float e = 0.15;
	float n1 = potential(p + vec2(0.0, e), t);
	float n2 = potential(p - vec2(0.0, e), t);
	float n3 = potential(p + vec2(e, 0.0), t);
	float n4 = potential(p - vec2(e, 0.0), t);
	return vec2(n1 - n2, n3 - n4) / (2.0 * e);
}

float lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 full = vec2(textureSize(effect_tex, 0));
	float ps = max(px_scale * full.x / max(tex_size.x, 1.0), 0.0001);
	float fps = max(history_fps, 1.0);
	int n = clamp(int(round(life * fps)), 1, 60);
	n = min(n, max(history_count - 2, 0));
	vec2 wdir = vec2(cos(radians(wind_angle)), sin(radians(wind_angle)));
	vec2 x = UV * full;
	vec4 now_c = texture(effect_tex, UV);
	float dens = 0.0;
	vec3 col = vec3(0.0);
	float wsum = 0.0;
	float thr = mix(0.10, 0.018, sensitivity);
	vec2 jit = kit_hash22(FRAGCOORD.xy + fract(time * 7.13) * 31.0) - 0.5;
	for (int k = 1; k <= 60; k++) {
		if (k > n) {
			break;
		}
		float age = float(k);
		float tk = time - age / fps;
		vec2 uvx = x / full;
		vec2 air = vec2(0.0, -rise) + wdir * wind;
		air += curl(x / (swirl_size * ps), tk) * swirl * 1.4;
		vec2 v = motion_at(flow_tex, clamp(uvx, vec2(0.0), vec2(1.0))) - (camera ? kit_global(global_tex, uvx) : vec2(0.0));
		vec2 cam = camera ? kit_global(global_tex, uvx) : vec2(0.0);
		x -= air * ps + v * drag * exp(-age * 0.12) + cam;
		vec2 s = x + jit * spread * ps * (1.5 + sqrt(age) * 2.2);
		vec2 su = s / full;
		if (su.x < 0.0 || su.y < 0.0 || su.x > 1.0 || su.y > 1.0) {
			continue;
		}
		vec4 a = history_frame(k, su, now_c);
		vec2 bu = su - 2.0 * cam / full;
		float d = 1e9;
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 o = vec2(float(i), float(j)) * shake * ps / full;
				vec4 b = history_frame(k + 2, clamp(bu + o, vec2(0.0), vec2(1.0)), a);
				d = min(d, max(abs(lum(a.rgb) - lum(b.rgb)), 0.6 * length(a.rgb - b.rgb)));
			}
		}
		float e = smoothstep(thr, thr * 2.5, d);
		float lf = age / float(max(n, 1));
		float fade = pow(max(1.0 - lf, 1e-4), 1.4) * smoothstep(0.0, 2.5, age);
		float w = e * fade;
		dens += w;
		vec3 ac = a.a > 0.0001 ? a.rgb / a.a : vec3(0.0);
		col += ac * w;
		wsum += w;
	}
	vec3 c = wsum > 1e-4 ? col / wsum : vec3(0.0);
	float D = 1.0 - exp(-dens * 0.45);
	COLOR = vec4(c, D);
}
