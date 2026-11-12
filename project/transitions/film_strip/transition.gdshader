shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float frames_by : hint_range(2.0, 24.0) = 7.0;
uniform float smear : hint_range(0.0, 1.0) = 0.55;
uniform float frame_line : hint_range(0.0, 0.2) = 0.06;
uniform float sprockets : hint_range(0.0, 1.0) = 0.7;
uniform float flicker : hint_range(0.0, 1.0) = 0.4;
uniform float jump : hint_range(0.0, 1.0) = 0.5;

vec4 strip_at(vec2 uv, float travel, float n) {
	float v = uv.y + travel;
	float frame_i = floor(v);
	float inside = fract(v);
	float gapv = max(frame_line, 0.0);
	if (inside < gapv * 0.5 || inside > 1.0 - gapv * 0.5) {
		return vec4(0.02, 0.018, 0.016, 1.0);
	}
	float sy = (inside - gapv * 0.5) / max(1.0 - gapv, 0.0001);
	float f = clamp(frame_i / max(n, 1.0), 0.0, 1.0);
	vec2 suv = vec2(uv.x, clamp(sy, 0.0, 1.0));
	return f < 0.5 ? from_at(suv) : to_at(suv);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float n = max(frames_by, 2.0);
	float ramp = p < 0.82 ? smoothstep(0.0, 0.3, p) * smoothstep(1.0, 0.72, p) : 0.0;
	float eased = p * p * (3.0 - 2.0 * p);
	float travel = eased * n;
	float settle = smoothstep(0.86, 1.0, p);
	float wobble = jump * 0.055 * sin((p - 0.86) * 38.0) * (1.0 - settle) * step(0.86, p);
	travel = mix(travel, round(travel) + wobble, settle);
	if (p >= 0.999) {
		travel = round(travel);
	}
	float speed = clamp(ramp, 0.0, 1.0);
	vec4 col = vec4(0.0);
	float taps = 1.0 + floor(speed * smear * 6.0);
	float total = 0.0;
	for (int i = 0; i < 7; i++) {
		if (float(i) >= taps) {
			break;
		}
		float off = (float(i) / max(taps, 1.0) - 0.5) * speed * smear * 0.75;
		col += strip_at(uv, travel + off, n);
		total += 1.0;
	}
	col /= max(total, 1.0);
	float ex = abs(uv.x - 0.5) * 2.0;
	float hole_zone = smoothstep(0.9, 0.97, ex) * sprockets;
	if (hole_zone > 0.0) {
		float hv = fract((uv.y + travel) * 4.0);
		float hole = (1.0 - smoothstep(0.22, 0.3, abs(hv - 0.5))) * (1.0 - smoothstep(0.955, 0.985, ex));
		col.rgb = mix(col.rgb, vec3(0.015), hole_zone * 0.85);
		col.rgb = mix(col.rgb, vec3(0.97, 0.95, 0.9), hole * hole_zone * 0.9);
	}
	float flick = 1.0 + flicker * 0.3 * (tr_hash(vec2(floor(p * 64.0), 3.0)) - 0.5) * speed;
	col.rgb *= flick;
	col.a = 1.0;
	return col;
}

void fragment() {
	COLOR = transition(UV);
}
