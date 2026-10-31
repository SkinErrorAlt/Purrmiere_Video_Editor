shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float sepia : hint_range(0.0, 1.0) = 0.85;
uniform float grain : hint_range(0.0, 1.0) = 0.35;
uniform float scratches : hint_range(0.0, 1.0) = 0.5;
uniform float flicker : hint_range(0.0, 1.0) = 0.5;
uniform float vignette : hint_range(0.0, 1.0) = 0.45;
uniform bool roll = true;
uniform float film_rate : hint_range(6.0, 30.0) = 18.0;

float h21(vec2 p, float k) {
	return tr_hash(p + vec2(k * 17.31, k * 5.77));
}

vec4 film_strip(vec2 uv, float p) {
	if (!roll) {
		return mix(from_at(uv), to_at(uv), smoothstep(0.45, 0.55, p));
	}
	float bar = 0.07;
	float slide = smoothstep(0.3, 0.7, p);
	float s = uv.y + slide * (1.0 + bar);
	if (s < 1.0) {
		return from_at(vec2(uv.x, s));
	} else if (s < 1.0 + bar) {
		float k = (s - 1.0) / bar;
		float line = smoothstep(0.0, 0.15, k) * smoothstep(1.0, 0.85, k);
		return vec4(vec3(0.03 + 0.03 * (1.0 - line)), 1.0);
	}
	return to_at(vec2(uv.x, s - 1.0 - bar));
}

vec2 weave_of(float n) {
	return (vec2(h21(vec2(n, 1.0), 1.0), h21(vec2(n, 2.0), 2.0)) - 0.5) * vec2(0.004, 0.006);
}

vec2 grime(vec2 uv, float n) {
	vec2 pix = floor(uv * frame_px / max(px_scale * 1.5, 1.0));
	float g = (h21(pix, n + 7.0) + h21(pix + 0.5, n + 9.0) - 1.0) * 0.22 * grain;
	float px = 1.0 / frame_px.x;
	float add = g;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float on = step(0.45, h21(vec2(n, fi + 11.0), 4.0));
		float x = h21(vec2(n, fi + 21.0), 5.0);
		float w = (0.6 + h21(vec2(fi, n), 6.0)) * px * max(px_scale * 2.0, 1.0);
		float bright = h21(vec2(fi, n + 3.0), 7.0) > 0.5 ? 0.55 : -0.45;
		float y_fade = 0.6 + 0.4 * sin(uv.y * (6.0 + fi * 3.0) + n);
		add += on * bright * exp(-abs(uv.x - x) / w) * y_fade * scratches;
	}
	vec2 dust_cell = floor(uv * vec2(24.0, 14.0));
	float dust_on = step(0.93, h21(dust_cell, n + 31.0));
	vec2 dust_at = (dust_cell + 0.2 + 0.6 * vec2(h21(dust_cell, n + 41.0), h21(dust_cell, n + 51.0))) / vec2(24.0, 14.0);
	float dust_r = 0.0015 + 0.004 * h21(dust_cell, n + 61.0);
	float dust = 1.0 - smoothstep(dust_r * 0.5, dust_r, length((uv - dust_at) * vec2(tr_ratio(), 1.0)));
	float keep = 1.0 - dust * dust_on * scratches * 0.85;
	float fl = 1.0 + (h21(vec2(n, 3.0), 3.0) - 0.5) * 0.35 * flicker;
	return vec2(add, keep * fl);
}

vec4 transition(vec2 uv) {
	float p = progress;
	float e = smoothstep(0.0, 0.22, p) * smoothstep(1.0, 0.78, p);
	if (e <= 0.0) {
		return film_strip(uv, p);
	}
	float fpos = p * max(duration, 0.05) * film_rate;
	float n0 = floor(fpos);
	float k = smoothstep(0.5, 1.0, fract(fpos));
	vec2 weave = mix(weave_of(n0), weave_of(n0 + 1.0), k) * e;
	vec4 c = film_strip(uv + weave, p);
	vec3 s = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	float l = dot(s, vec3(0.299, 0.587, 0.114));
	vec3 tone = l * vec3(1.08, 0.86, 0.6) + vec3(0.03, 0.01, -0.02);
	s = mix(s, tone, sepia * e);
	vec2 g = mix(grime(uv, n0), grime(uv, n0 + 1.0), k);
	s = s * mix(1.0, g.y, e) + vec3(g.x * e);
	float vig = 1.0 - smoothstep(0.25, 0.85, length(uv - 0.5) * 1.15) * vignette * e;
	s = clamp(s * vig, 0.0, 1.0);
	return vec4(s * c.a, c.a);
}

void fragment() {
	COLOR = transition(UV);
}
