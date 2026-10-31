shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform vec2 centre = vec2(0.5, 0.5);
uniform float waves : hint_range(2.0, 60.0) = 16.0;
uniform float strength : hint_range(0.0, 80.0) = 18.0;
uniform float damping : hint_range(0.0, 1.0) = 0.5;
uniform int mode = 0;
uniform float softness : hint_range(0.0, 0.3) = 0.03;
uniform float shine : hint_range(0.0, 1.0) = 0.3;

vec4 transition(vec2 uv) {
	float p = progress;
	vec2 c = tr_world(centre);
	vec2 rel = tr_world(uv) - c;
	vec2 h = vec2(tr_ratio() * 0.5, 0.5);
	float reach = length(abs(c) + h);
	float d = length(rel);
	vec2 dir = d > 0.000001 ? rel / d : vec2(0.0);
	float soft = max(softness, 0.002);
	float grow = 1.0 - pow(1.0 - p, 1.6);
	float r = mix(-soft, reach + soft, grow);
	float inside = r - d;
	float k = waves * 2.0 * TR_PI;
	float decay = exp(-max(inside, 0.0) * damping * 6.0);
	float ring = smoothstep(-soft, soft * 0.5, inside);
	float env = sin(TR_PI * p);
	float amp = strength * px_scale / max(frame_px.y, 1.0);
	float wave = sin(k * inside) * decay * ring * env;
	float slope = cos(k * inside) * decay * ring * env;
	vec2 src = tr_frame_uv(tr_world(uv) - dir * amp * wave);
	vec4 col;
	if (mode == 1) {
		col = mix(from_clamped(src), to_at(uv), p);
	} else {
		float m = smoothstep(-soft, soft, inside);
		col = mix(from_clamped(src), to_clamped(src), m);
	}
	return tr_shade(col, 1.0 + shine * 0.4 * slope);
}

void fragment() {
	COLOR = transition(UV);
}
