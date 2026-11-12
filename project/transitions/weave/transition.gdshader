shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int rows : hint_range(2, 32) = 6;
uniform int cols : hint_range(2, 32) = 9;
uniform float shade : hint_range(0.0, 1.0) = 0.45;
uniform float stagger : hint_range(0.0, 0.8) = 0.6;
uniform int curve = 1;

float band_progress(float p, float lane, float lanes) {
	float sp = clamp(stagger, 0.0, 0.8);
	float span = max(1.0 - sp, 0.2);
	float start = lanes <= 1.0 ? 0.0 : sp * lane / (lanes - 1.0);
	return clamp((p - start) / span, 0.0, 1.0);
}

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	float nr = float(max(rows, 2));
	float nc = float(max(cols, 2));
	float ri = floor(uv.y * nr);
	float ci = floor(uv.x * nc);
	float soft = 1.5 / max(frame_px.x, 1.0);
	float hp = band_progress(p, ri, nr);
	float vp = band_progress(p, ci, nc);
	float ry0 = fract(uv.y * nr);
	float cx0 = fract(uv.x * nc);
	float widen = mix(0.42, 0.5, smoothstep(0.84, 1.0, p));
	float h_band = 1.0 - smoothstep(widen - 0.035, widen + 0.035, abs(ry0 - 0.5));
	float v_band = 1.0 - smoothstep(widen - 0.035, widen + 0.035, abs(cx0 - 0.5));
	float h_cover = (1.0 - smoothstep(hp - soft, hp + soft, uv.x)) * h_band;
	float v_cover = (1.0 - smoothstep(vp - soft, vp + soft, uv.y)) * v_band;
	bool h_on_top = mod(ri + ci, 2.0) < 1.0;
	float m = max(max(h_cover, v_cover), smoothstep(0.9, 1.0, p));
	float light = 1.0;
	float cross_amount = h_cover * v_cover;
	if (cross_amount > 0.0) {
		float across = h_on_top ? fract(uv.y * nr) : fract(uv.x * nc);
		float seam = smoothstep(0.1, 0.0, across) + smoothstep(0.9, 1.0, across);
		float under = h_on_top ? 0.0 : 1.0;
		float fade = 1.0 - smoothstep(0.8, 1.0, p);
		light = 1.0 - clamp(shade, 0.0, 1.0) * cross_amount * (0.18 * under + 0.3 * seam) * fade;
	}
	float fade_all = 1.0 - smoothstep(0.8, 1.0, p);
	float ry = fract(uv.y * nr);
	float cx = fract(uv.x * nc);
	float h_edge = smoothstep(0.09, 0.0, ry) + smoothstep(0.91, 1.0, ry);
	float v_edge = smoothstep(0.09, 0.0, cx) + smoothstep(0.91, 1.0, cx);
	float own_edge = h_cover > v_cover ? h_edge : v_edge;
	light *= 1.0 - clamp(shade, 0.0, 1.0) * 0.4 * own_edge * m * fade_all;
	vec4 col = mix(from_at(uv), to_at(uv), m);
	col.rgb *= light;
	return col;
}

void fragment() {
	COLOR = transition(UV);
}
