shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float grain : hint_range(1.0, 16.0) = 2.0;
uniform bool colour = false;
uniform float rate : hint_range(4.0, 60.0) = 24.0;
uniform float roll : hint_range(0.0, 1.0) = 0.5;
uniform float hold : hint_range(0.0, 0.8) = 0.15;

vec4 transition(vec2 uv) {
	float p = progress;
	float peak = 1.0 - abs(2.0 * p - 1.0);
	float s = smoothstep(0.0, 1.0 - hold, peak);
	float q = floor(p * rate);
	float row = floor(uv.y * frame_px.y / max(grain * px_scale, 1.0));
	float jitter = (tr_hash(vec2(row * 0.13, q + 3.0)) - 0.5) * 0.04 * roll * s;
	float wobble = sin(uv.y * 40.0 + q * 2.1) * 0.006 * roll * s;
	vec2 src = uv + vec2(jitter + wobble, 0.0);
	float m = clamp((p - 0.45) / 0.1, 0.0, 1.0);
	vec4 pic = mix(from_clamped(src), to_clamped(src), m);
	if (s <= 0.0) {
		pic = mix(from_at(uv), to_at(uv), m);
	}
	vec2 g = floor(uv * frame_px / max(grain * px_scale, 1.0));
	vec2 key = g + vec2(q * 37.0, q * 17.0);
	float n = tr_hash(key);
	vec3 snow = vec3(n);
	if (colour) {
		snow = vec3(n, tr_hash(key + vec2(91.0, 7.0)), tr_hash(key + vec2(13.0, 57.0)));
		snow = mix(vec3(n), snow, 0.6);
	}
	float lines = 0.82 + 0.18 * step(0.5, fract(uv.y * frame_px.y / max(2.0 * px_scale, 1.0) * 0.5));
	float bar = smoothstep(0.0, 0.08, fract(uv.y * 0.8 - p * rate * 0.07)) * (1.0 - smoothstep(0.08, 0.2, fract(uv.y * 0.8 - p * rate * 0.07)));
	snow = snow * lines + vec3(0.35) * bar * roll;
	vec4 noise_col = vec4(clamp(snow, 0.0, 1.0), 1.0);
	float k = s * amount;
	vec4 col = mix(pic, noise_col, k);
	return col;
}

void fragment() {
	COLOR = transition(UV);
}
