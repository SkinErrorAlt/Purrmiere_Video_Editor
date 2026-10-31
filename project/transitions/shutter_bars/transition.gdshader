shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int bars : hint_range(2, 30) = 8;
uniform int orientation = 0;
uniform vec4 colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float stagger : hint_range(0.0, 0.9) = 0.4;
uniform float hold : hint_range(0.0, 0.6) = 0.1;
uniform bool alternate = false;
uniform int curve = 1;

float w_sweep(float v, float p, float soft) {
	float s = max(soft, 0.0001);
	float e = mix(-s, 1.0, p);
	return 1.0 - smoothstep(e, e + s, v);
}

vec4 transition(vec2 uv) {
	int kind = curve == 1 ? 3 : 0;
	float n = float(max(bars, 1));
	float c = orientation == 0 ? uv.y : uv.x;
	float len = orientation == 0 ? frame_px.y : frame_px.x;
	float idx = min(floor(c * n), n - 1.0);
	float f = c * n - idx;
	if (alternate && mod(idx, 2.0) > 0.5) {
		f = 1.0 - f;
	}
	float k = n > 1.0 ? idx / (n - 1.0) : 0.0;
	float st = clamp(stagger, 0.0, 0.9);
	float q = clamp((progress - st * k) / (1.0 - st), 0.0, 1.0);
	float span = (1.0 - clamp(hold, 0.0, 0.6)) * 0.5;
	float close = tr_ease(clamp(q / span, 0.0, 1.0), kind);
	float open = tr_ease(clamp((q - (1.0 - span)) / span, 0.0, 1.0), kind);
	float a = n / len;
	float c_col = w_sweep(f, close, a);
	float c_to = min(w_sweep(f, open, a), c_col);
	vec4 col = vec4(colour.rgb * colour.a, colour.a);
	return from_at(uv) * (1.0 - c_col) + col * (c_col - c_to) + to_at(uv) * c_to;
}

void fragment() {
	COLOR = transition(UV);
}
