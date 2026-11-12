shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float splats : hint_range(2.0, 14.0) = 5.0;
uniform float spread : hint_range(0.5, 2.5) = 1.15;
uniform float ragged : hint_range(0.0, 1.0) = 0.5;
uniform float droplets : hint_range(0.0, 1.0) = 0.5;
uniform vec4 paint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float paint_amount : hint_range(0.0, 1.0) = 0.0;
uniform float softness : hint_range(0.0, 0.2) = 0.012;

float blob_at(vec2 pos, vec2 cell, float cell_w, float p, out float fresh) {
	vec2 h = tr_hash2(cell + 11.3);
	float h3 = tr_hash(cell * 1.71 + 5.2);
	float h4 = tr_hash(cell * 2.33 + 19.7);
	vec2 at = (cell + vec2(0.18, 0.18) + h * 0.64) * cell_w;
	float span = 0.42;
	float start = h3 * (1.0 - span);
	float t = clamp((p - start) / span, 0.0, 1.0);
	fresh = t;
	if (t <= 0.0) {
		return 0.0;
	}
	float grow = 1.0 - pow(1.0 - t, 2.6);
	float over = 1.0 + 0.16 * sin(t * TR_PI) * (1.0 - t);
	float radius = cell_w * 0.92 * spread * grow * over;
	vec2 d = pos - at;
	float ang = atan(d.y, d.x);
	float lobes = 3.0 + floor(h4 * 4.0);
	float wob = 1.0 + ragged * (0.22 * sin(ang * lobes + h4 * 24.0) + 0.11 * sin(ang * (lobes * 2.0 + 3.0) - h3 * 17.0) + 0.06 * sin(ang * 11.0 + h3 * 7.0));
	float dist = length(d) / max(radius * wob, 0.00001);
	float s = max(softness, 0.004);
	float m = 1.0 - smoothstep(1.0 - s, 1.0, dist);
	if (droplets > 0.0) {
		for (int k = 0; k < 3; k++) {
			vec2 dh = tr_hash2(cell * 3.0 + float(k) * 7.31 + 2.0);
			float ang2 = dh.x * TR_PI * 2.0;
			float far = (1.25 + dh.y * 1.1) * radius;
			vec2 dat = at + vec2(cos(ang2), sin(ang2)) * far;
			float dr = radius * (0.08 + dh.y * 0.14) * droplets;
			float dd = length(pos - dat) / max(dr, 0.00001);
			m = max(m, (1.0 - smoothstep(1.0 - s * 3.0, 1.0, dd)) * step(0.1, t));
		}
	}
	return m;
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float ar = tr_ratio();
	vec2 pos = vec2(uv.x * ar, uv.y);
	float n = max(splats, 2.0);
	float cell_w = ar / n;
	vec2 base = floor(pos / cell_w);
	float cover = 0.0;
	float fresh_top = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			float f = 0.0;
			float m = blob_at(pos, base + vec2(float(i), float(j)), cell_w, p, f);
			if (m > cover) {
				cover = m;
				fresh_top = f;
			}
		}
	}
	cover = max(cover, smoothstep(0.93, 1.0, p));
	vec4 a = from_at(uv);
	vec4 b = to_at(uv);
	vec4 shown = b;
	if (paint_amount > 0.0) {
		float clear_up = smoothstep(0.35, 0.95, fresh_top);
		shown = mix(mix(b, paint, paint_amount), b, clear_up);
	}
	return mix(a, shown, cover);
}

void fragment() {
	COLOR = transition(UV);
}
