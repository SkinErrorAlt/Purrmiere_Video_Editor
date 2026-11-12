shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int blades : hint_range(3, 14) = 7;
uniform int mode : hint_range(0, 2) = 0;
uniform float twist : hint_range(0.0, 90.0) = 26.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float rim : hint_range(0.0, 1.0) = 0.45;
uniform vec4 body : source_color = vec4(0.02, 0.02, 0.025, 1.0);
uniform float softness : hint_range(0.0, 0.1) = 0.004;

float blade_field(vec2 pos, float open, float spin) {
	int n = clamp(blades, 3, 14);
	float step_a = TR_PI * 2.0 / float(n);
	float d = -10.0;
	for (int i = 0; i < 14; i++) {
		if (i >= n) {
			break;
		}
		float a = float(i) * step_a + spin;
		vec2 dir = vec2(cos(a), sin(a));
		d = max(d, dot(pos, dir) - open);
	}
	return d;
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	vec4 a = from_at(uv);
	vec4 b = to_at(uv);
	float shut = 1.0 - abs(2.0 * p - 1.0);
	vec4 inner = p < 0.5 ? a : b;
	vec4 outer = body;
	if (mode == 1) {
		shut = 1.0 - p;
		inner = b;
		outer = a;
	} else if (mode == 2) {
		shut = p;
		inner = a;
		outer = b;
	}
	shut = clamp(shut, 0.0, 1.0);
	float open = mix(1.35, 0.0, shut);
	float spin = radians(twist) * shut;
	vec2 pos = (uv - centre) * vec2(tr_ratio(), 1.0);
	float d = blade_field(pos, open, spin);
	float s = max(softness, 1.5 / max(frame_px.y, 1.0));
	float inside = 1.0 - smoothstep(-s, s, d);
	vec4 out_col = mix(outer, inner, inside);
	float edge = exp(-abs(d) / max(s * 3.0, 0.001)) * rim * clamp(shut * 3.0, 0.0, 1.0);
	out_col.rgb += vec3(edge * 0.9, edge * 0.94, edge);
	out_col.a = max(out_col.a, mix(outer.a, inner.a, inside));
	return out_col;
}

void fragment() {
	COLOR = transition(UV);
}
