shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int columns = 40;
uniform float spread : hint_range(0.0, 0.9) = 0.45;
uniform float jitter : hint_range(0.0, 1.0) = 0.35;
uniform float acceleration : hint_range(0.0, 1.0) = 0.6;

vec4 transition(vec2 uv) {
	float n = float(max(columns, 1));
	float col = floor(uv.x * n);
	float smooth_part = tr_noise(vec2(col * 0.21, 3.7)) * 0.7 + tr_noise(vec2(col * 0.05, 9.1)) * 0.3;
	float rough_part = tr_hash(vec2(col + 0.5, 1.3));
	float delay = clamp(spread, 0.0, 0.9) * clamp(mix(smooth_part, rough_part, clamp(jitter, 0.0, 1.0)), 0.0, 1.0);
	float lp = clamp((progress - delay) / (1.0 - delay), 0.0, 1.0);
	float shift = mix(lp, lp * lp, clamp(acceleration, 0.0, 1.0));
	vec2 suv = vec2(uv.x, uv.y - shift);
	float cov = clamp(suv.y * frame_px.y + 0.5, 0.0, 1.0);
	return mix(to_at(uv), from_clamped(suv), cov);
}

void fragment() {
	COLOR = transition(UV);
}
