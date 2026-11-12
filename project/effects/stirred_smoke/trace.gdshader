shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/stirred_smoke/sim.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float clip_time = 0.0;
uniform float memory : hint_range(0.3, 2.0) = 1.0;
uniform int source : hint_range(0, 2) = 0;
uniform float rise : hint_range(-1.0, 1.0) = 0.35;
uniform float swirl : hint_range(0.0, 1.0) = 0.5;
uniform float stir : hint_range(0.0, 1.0) = 0.6;
uniform float amount : hint_range(0.0, 1.0) = 0.6;
uniform float threshold : hint_range(0.0, 1.0) = 0.6;
uniform int seed : hint_range(0, 9999) = 0;

const int STEPS = 24;

vec4 frame_at(int age, vec2 uv) {
	vec4 now = texture(effect_tex, uv);
	if (age <= 0) {
		return now;
	}
	return history_frame(age, uv, now);
}

float lum_at(int age, vec2 uv) {
	vec4 c = frame_at(age, uv);
	return sim_luma(c.rgb / max(c.a, 0.001));
}

float moved(int age, vec2 uv, vec2 r) {
	float m = 0.0;
	for (int k = 0; k < 2; k++) {
		vec2 o = (k == 0 ? vec2(-0.5, -0.3) : vec2(0.5, 0.3)) * r;
		vec3 a = frame_at(age, uv + o).rgb;
		vec3 b = frame_at(age + 2, uv + o).rgb;
		vec3 d = abs(a - b);
		m += max(max(d.r, d.g), d.b);
	}
	return m * 0.5;
}

vec2 curl_noise(vec2 p, float t, float sd) {
	float e = 0.01;
	float n0 = sim_fbm(p * 3.0 + vec2(0.0, t * 0.25) + sd, 3);
	float nx = sim_fbm((p + vec2(e, 0.0)) * 3.0 + vec2(0.0, t * 0.25) + sd, 3);
	float ny = sim_fbm((p + vec2(0.0, e)) * 3.0 + vec2(0.0, t * 0.25) + sd, 3);
	return vec2(ny - n0, -(nx - n0)) / e;
}

void fragment() {
	vec2 tsz = vec2(textureSize(effect_tex, 0));
	vec2 asp = vec2(tsz.x / max(tsz.y, 1.0), 1.0);
	float fps = max(history_fps, 1.0);
	float reach = min(memory * fps, float(history_count));
	reach = min(reach, floor(clip_time * fps + 0.0001));
	float sd = float(seed) * 0.37;
	vec2 p = UV;
	vec3 acc = vec3(0.0);
	float dens = 0.0;
	float dt_frames = max(reach, 1.0) / float(STEPS);
	float dt = dt_frames / fps;
	vec2 mr = vec2(10.0) / tsz.y * vec2(1.0 / asp.x, 1.0);
	for (int k = 0; k <= STEPS; k++) {
		float agef = float(k) * dt_frames;
		if (agef > reach + 0.001) {
			break;
		}
		int age = int(round(agef));
		float tt = clip_time - agef / fps;
		vec4 c = frame_at(age, p);
		vec3 col = c.rgb / max(c.a, 0.001);
		float l = sim_luma(col);
		float e = 0.0;
		if (source == 0) {
			e = smoothstep(threshold, threshold + 0.2, l);
		} else if (source == 1) {
			e = smoothstep(0.05, 0.22, moved(age, p, mr * 1.5));
		} else {
			e = smoothstep(1.0 - threshold, 1.0 - threshold - 0.25, l);
		}
		float fade = exp(-agef / max(reach, 1.0) * 2.2);
		float w = e * fade * (k == 0 ? 0.5 : 1.0);
		acc += col * w;
		dens += w;
		vec2 v = vec2(0.0, -rise * 0.6);
		vec2 q = vec2(p.x * asp.x, p.y);
		v += curl_noise(q, tt, sd) * 0.035 * swirl;
		if (stir > 0.0) {
			float m0 = moved(age, p, mr);
			float mx = moved(age, p + vec2(mr.x * 2.0, 0.0), mr) - m0;
			float my = moved(age, p + vec2(0.0, mr.y * 2.0), mr) - m0;
			v += vec2(my, -mx) * 7.0 * stir + vec2(0.0, -m0 * 0.4 * stir);
		}
		p -= vec2(v.x / asp.x, v.y) * dt;
		if (p.x < -0.1 || p.x > 1.1 || p.y < -0.1 || p.y > 1.2) {
			break;
		}
	}
	vec3 colour = acc / max(dens, 0.0001);
	float a = 1.0 - exp(-dens / float(STEPS) * 7.5 * amount);
	COLOR = vec4(clamp(colour, 0.0, 1.0) * a, a);
}
