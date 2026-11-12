shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float gauge : hint_range(6.0, 80.0) = 34.0;
uniform float courses : hint_range(4.0, 60.0) = 22.0;
uniform float yarn : hint_range(0.1, 0.5) = 0.28;
uniform float relief : hint_range(0.0, 1.0) = 0.7;
uniform float overlap : hint_range(0.02, 0.6) = 0.12;
uniform bool from_left = true;

float leg(vec2 q, vec2 a, vec2 b) {
	vec2 pa = q - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.00001), 0.0, 1.0);
	return length(pa - ba * h);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float nx = max(gauge, 6.0);
	float ny = max(courses, 4.0);
	float row = floor(uv.y * ny);
	float within_y = fract(uv.y * ny);
	float span = clamp(overlap, 0.02, 0.6);
	float start = (row / max(ny - 1.0, 1.0)) * (1.0 - span);
	float rowt = clamp((p - start) / span, 0.0, 1.0);
	float sx = from_left ? uv.x : 1.0 - uv.x;
	float soft = 2.0 / max(frame_px.x, 1.0);
	float knitted = 1.0 - smoothstep(rowt - soft, rowt + soft, sx);
	if (knitted <= 0.0) {
		return from_at(uv);
	}
	float relief_now = relief * (1.0 - smoothstep(0.86, 1.0, p));
	float lean = mod(row, 2.0) < 1.0 ? 1.0 : -1.0;
	float within_x = fract(uv.x * nx);
	vec2 q = vec2(within_x, within_y);
	float t = max(yarn, 0.1) * 0.5;
	float d1 = leg(q, vec2(0.5 - 0.42 * lean, 1.0), vec2(0.5, 0.12));
	float d2 = leg(q, vec2(0.5 + 0.42 * lean, 1.0), vec2(0.5, 0.12));
	float d = min(d1, d2);
	float strand = 1.0 - smoothstep(t - 0.03, t + 0.03, d);
	float round_up = clamp(1.0 - d / max(t, 0.0001), 0.0, 1.0);
	vec4 wool = to_at(uv);
	float lit = mix(0.72, 1.28, pow(round_up, 0.6));
	wool.rgb *= mix(1.0, lit, relief_now);
	float groove = (1.0 - strand) * relief_now * 0.45;
	vec4 behind = to_at(uv);
	behind.rgb *= 1.0 - groove;
	vec4 fabric = mix(behind, wool, strand);
	float tip = smoothstep(soft * 6.0, 0.0, abs(sx - rowt)) * step(0.001, rowt) * (1.0 - step(0.999, rowt));
	fabric.rgb = mix(fabric.rgb, fabric.rgb * 1.25 + vec3(0.1), tip * relief_now);
	return mix(from_at(uv), fabric, knitted);
}

void fragment() {
	COLOR = transition(UV);
}
