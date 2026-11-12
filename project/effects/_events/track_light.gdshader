shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/_events/ev.gdshaderinc"

uniform float settle : hint_range(0.2, 2.0) = 0.8;
uniform float hunting : hint_range(0.0, 1.0) = 0.45;
uniform float wb_lag : hint_range(0.0, 1.0) = 0.7;
uniform float delay : hint_range(0.0, 0.3) = 0.07;

vec3 lv(sampler2D st, int a) {
	return ev_stat(st, a).rgb * 10.0 - 10.0;
}

float lum(vec3 l) {
	return max(log2(dot(exp2(l), vec3(0.2126, 0.7152, 0.0722))), -7.0);
}

float step_resp(float t, float st, float zeta, float win) {
	float tt = t - delay;
	if (tt <= 0.0) {
		return 0.0;
	}
	float w = 4.2 / max(st, 0.05);
	float g;
	if (zeta >= 0.999) {
		g = 1.0 - (1.0 + w * tt) * exp(-w * tt);
	} else {
		float wd = w * sqrt(1.0 - zeta * zeta);
		g = 1.0 - exp(-zeta * w * tt) * (cos(wd * tt) + zeta / sqrt(1.0 - zeta * zeta) * sin(wd * tt));
	}
	return mix(g, 1.0, smoothstep(win * 0.7, win, t));
}

void fragment() {
	float fps = max(history_fps, 1.0);
	int n = 0;
	for (int a = 1; a <= 61; a++) {
		if (ev_stat(TEXTURE, a).a < 0.5) {
			break;
		}
		n = a;
	}
	float win = float(n) / fps;
	float zeta = mix(1.0, 0.32, clamp(hunting, 0.0, 1.0));
	vec3 now = lv(TEXTURE, 0);
	vec3 lag_e = lv(TEXTURE, n);
	vec3 lag_w = lag_e;
	for (int k = 0; k <= 60; k++) {
		if (k >= n) {
			break;
		}
		vec3 d = lv(TEXTURE, k) - lv(TEXTURE, k + 1);
		float t = float(k) / fps;
		lag_e += d * step_resp(t, settle, zeta, win);
		lag_w += d * step_resp(t, settle * 1.7, 1.0, win);
	}
	float e = n > 0 ? lum(now) - lum(lag_e) : 0.0;
	e = sign(e) * max(abs(e) - 0.25, 0.0);
	vec3 cn = max(now, vec3(-7.0));
	vec3 cl = max(lag_w, vec3(-7.0));
	vec3 wb = n > 0 ? ((vec3(lum(cl)) - cl) - (vec3(lum(cn)) - cn)) * wb_lag : vec3(0.0);
	COLOR = vec4(clamp(e / 8.0 + 0.5, 0.0, 1.0), clamp(wb / 4.0 + 0.5, 0.0, 1.0));
}
