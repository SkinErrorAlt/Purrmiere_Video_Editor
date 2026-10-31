shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float scale : hint_range(1.0, 60.0) = 4.0;
uniform float softness : hint_range(0.0, 0.5) = 0.01;
uniform int detail : hint_range(1, 5) = 1;
uniform bool invert = false;

float field(vec2 q) {
	float v = 0.0;
	float a = 0.5;
	float total = 0.0;
	for (int i = 0; i < 5; i++) {
		if (i >= detail) {
			break;
		}
		v += a * tr_noise(q);
		total += a;
		q = q * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	v /= max(total, 0.0001);
	float stretch = 1.5 + 0.45 * float(detail - 1);
	return clamp((v - 0.5) * stretch + 0.5, 0.0, 1.0);
}

vec4 transition(vec2 uv) {
	float p = progress;
	float s = max(softness, 0.0005);
	vec2 q = vec2(uv.x * tr_ratio(), uv.y) * scale / tr_ratio();
	float n = field(q);
	if (invert) {
		n = 1.0 - n;
	}
	float edge = mix(-s, 1.0 + s, p);
	float keep = smoothstep(edge - s, edge + s, n);
	return mix(from_at(uv), to_at(uv), 1.0 - keep);
}

void fragment() {
	COLOR = transition(UV);
}
