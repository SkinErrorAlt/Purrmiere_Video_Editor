shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int blots : hint_range(1, 6) = 3;
uniform float spread : hint_range(0.0, 1.0) = 0.7;
uniform float rim : hint_range(0.0, 80.0) = 18.0;
uniform vec4 ink_colour : source_color = vec4(0.03, 0.03, 0.05, 1.0);
uniform float softness : hint_range(0.0, 0.2) = 0.01;
uniform int curve = 1;

vec2 blot_centre(int k) {
	vec2 h = tr_hash2(vec2(float(k) * 1.7 + 0.3, 5.1));
	return (h - 0.5) * vec2(tr_ratio(), 1.0) * (k == 0 ? 0.35 : 0.85);
}

float blot_reach(int k) {
	return k == 0 ? 1.0 : 0.55 + 0.35 * tr_hash(vec2(float(k) + 0.5, 9.2));
}

float spread_rank(float f, float samples[45], float h) {
	float acc = 0.0;
	for (int i = 0; i < 45; i++) {
		acc += smoothstep(samples[i] - h, samples[i] + h, f);
	}
	return acc / 45.0;
}

vec4 transition(vec2 uv) {
	int kind = curve == 1 ? 3 : (curve == 2 ? 2 : 0);
	float p = tr_ease(progress, kind);
	vec2 w = tr_world(uv);
	int nb = clamp(blots, 1, 6);
	vec2 cs[6];
	float rs[6];
	for (int k = 0; k < 6; k++) {
		cs[k] = blot_centre(k);
		rs[k] = 1.0 / blot_reach(k);
	}
	float f = 1000000.0;
	for (int k = 0; k < 6; k++) {
		if (k < nb) {
			f = min(f, length(w - cs[k]) * rs[k]);
		}
	}
	float samples[45];
	float f_far = 0.0;
	for (int j = 0; j < 9; j++) {
		for (int i = 0; i < 5; i++) {
			vec2 g = tr_world(vec2(float(j) / 8.0, float(i) / 4.0));
			float fg = 1000000.0;
			for (int k = 0; k < 6; k++) {
				if (k < nb) {
					fg = min(fg, length(g - cs[k]) * rs[k]);
				}
			}
			samples[j * 5 + i] = fg;
			f_far = max(f_far, fg);
		}
	}
	float amp = clamp(spread, 0.0, 1.0) * 0.12 * (1.0 + f_far);
	float n = 0.6 * tr_fbm(w * 3.0 + vec2(11.0, 4.0)) + 0.4 * tr_fbm(w * 12.0 + vec2(2.0, 19.0));
	float fn = f + amp * (n - 0.5);
	float h = 0.12 * f_far + 0.001;
	float px_w = 1.0 / frame_px.y;
	float v_in = spread_rank(fn, samples, h);
	float v_rim = spread_rank(fn - rim * px_scale * px_w, samples, h);
	float v_px = spread_rank(fn + 1.5 * px_w, samples, h);
	float s = max(softness, max(v_px - v_in, 0.0001));
	float e = mix(-s, 1.0 + s, p);
	float c_to = 1.0 - smoothstep(e - s, e, v_in);
	float c_all = max(1.0 - smoothstep(e - s, e, v_rim), c_to);
	float bleed = 0.75 + 0.5 * tr_noise(w * 40.0);
	vec4 ink = vec4(clamp(ink_colour.rgb * bleed, 0.0, 1.0) * ink_colour.a, ink_colour.a);
	return from_at(uv) * (1.0 - c_all) + ink * (c_all - c_to) + to_at(uv) * c_to;
}

void fragment() {
	COLOR = transition(UV);
}
