shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int origin = 0;
uniform float rings : hint_range(1.0, 30.0) = 7.0;
uniform float strength : hint_range(0.0, 80.0) = 32.0;
uniform float softness : hint_range(0.01, 0.5) = 0.14;
uniform float shine : hint_range(0.0, 1.0) = 0.5;

vec2 origin_point() {
	vec2 h = vec2(tr_ratio() * 0.5, 0.5);
	if (origin == 1) {
		return vec2(-h.x, h.y);
	} else if (origin == 2) {
		return vec2(h.x, h.y);
	} else if (origin == 3) {
		return vec2(-h.x, -h.y);
	} else if (origin == 4) {
		return vec2(h.x, -h.y);
	}
	return vec2(0.0);
}

vec4 transition(vec2 uv) {
	float p = progress;
	vec2 o = origin_point();
	vec2 rel = tr_world(uv) - o;
	vec2 h = vec2(tr_ratio() * 0.5, 0.5);
	float reach = length(abs(o) + h);
	float d = length(rel);
	vec2 dir = d > 0.000001 ? rel / d : vec2(0.0);
	float soft = softness * reach;
	float front = mix(-soft, reach + soft, p);
	float behind = front - d;
	float k = rings * 2.0 * TR_PI / reach;
	float phase = k * (d - front);
	float packet = exp(-max(behind, 0.0) / (reach * 0.3)) * smoothstep(-soft * 1.5, 0.0, behind);
	float env = sin(TR_PI * p);
	float amp = strength * px_scale / max(frame_px.y, 1.0);
	float disp = amp * sin(phase) * packet * env;
	float slope = cos(phase) * packet * env;
	vec2 src = tr_frame_uv(tr_world(uv) - dir * disp);
	float m = 1.0 - smoothstep(-soft, soft, d - front);
	vec4 c = mix(from_clamped(src), to_clamped(src), m);
	return tr_shade(c, 1.0 + shine * 0.6 * slope);
}

void fragment() {
	COLOR = transition(UV);
}
