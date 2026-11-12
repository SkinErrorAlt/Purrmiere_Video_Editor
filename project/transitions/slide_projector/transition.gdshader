shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float hold : hint_range(0.0, 0.4) = 0.14;
uniform float lamp : hint_range(0.0, 2.0) = 0.55;
uniform float bounce : hint_range(0.0, 1.0) = 0.5;
uniform float gate : hint_range(0.0, 0.12) = 0.03;
uniform float dust : hint_range(0.0, 1.0) = 0.4;
uniform vec4 warm : source_color = vec4(1.0, 0.95, 0.84, 1.0);

float gate_mask(vec2 uv) {
	float r = max(gate, 0.0);
	vec2 q = abs(uv - 0.5) - (vec2(0.5) - vec2(r));
	float d = length(max(q, vec2(0.0))) - r;
	return 1.0 - smoothstep(-0.004, 0.004, d);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float h = clamp(hold, 0.0, 0.4);
	float out_end = (1.0 - h) * 0.5;
	float in_start = out_end + h;
	vec4 col = vec4(0.0, 0.0, 0.0, 1.0);
	float empty = 1.0;
	if (p < out_end) {
		float t = p / max(out_end, 0.0001);
		float lift = t * t * 1.15;
		vec2 suv = uv + vec2(0.0, lift);
		if (suv.y <= 1.0) {
			col = from_clamped(suv);
			empty = 0.0;
		}
	} else if (p >= in_start) {
		float t = (p - in_start) / max(1.0 - in_start, 0.0001);
		float e = 1.0 - pow(1.0 - t, 3.0);
		float wob = bounce * 0.07 * sin(t * TR_PI * 2.6) * (1.0 - t);
		float drop = (1.0 - e) * 1.15 - wob;
		vec2 suv = uv - vec2(0.0, drop);
		if (suv.y >= 0.0) {
			col = to_clamped(suv);
			empty = 0.0;
		}
	}
	float g = gate_mask(uv);
	float vign = 1.0 - 0.35 * pow(length((uv - 0.5) * vec2(1.1, 1.0)) * 1.42, 2.4);
	float burn = empty * lamp;
	col.rgb = col.rgb * mix(1.0, vign, 0.85) + warm.rgb * burn * (0.55 + 0.45 * vign);
	float lit = lamp * 0.14 * (1.0 - empty);
	col.rgb += warm.rgb * lit * vign;
	float motes = step(0.9965, tr_hash(floor(uv * frame_px * 0.5) + floor(p * 24.0)));
	col.rgb += warm.rgb * motes * dust * 0.55 * (0.2 + burn);
	col.rgb *= g;
	col.a = 1.0;
	return col;
}

void fragment() {
	COLOR = transition(UV);
}
