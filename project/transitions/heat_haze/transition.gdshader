shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float strength : hint_range(0.0, 0.1) = 0.012;
uniform float scale : hint_range(1.0, 40.0) = 16.0;
uniform float rise : hint_range(0.0, 10.0) = 3.0;
uniform float warmth : hint_range(0.0, 1.0) = 0.3;

vec4 transition(vec2 uv) {
	float p = progress;
	float s = sin(TR_PI * clamp(p, 0.0, 1.0));
	float w = smoothstep(0.3, 0.7, p);
	if (s <= 0.0 || !tr_inside(uv)) {
		return mix(from_at(uv), to_at(uv), w);
	}
	float env = s * s;
	vec2 q = vec2(uv.x * tr_ratio(), uv.y);
	float climb = p * rise;
	vec2 n1 = vec2(q.x * scale * 0.6, q.y * scale + climb * 2.0);
	vec2 n2 = vec2(q.x * scale * 1.3 + 5.2, q.y * scale * 2.1 + climb * 3.1);
	float dx = (tr_noise(n1) - 0.5) + 0.5 * (tr_noise(n2) - 0.5);
	float dy = (tr_noise(n1 + vec2(13.7, 0.0)) - 0.5) * 0.4;
	float ripple = sin(q.y * scale * 6.0 + climb * 9.0 + dx * 6.0) * 0.25;
	vec2 off = vec2(dx + ripple * 0.5, dy) * strength * env * 2.0;
	float heat_rise = mix(1.0, 0.6 + 0.8 * (1.0 - uv.y), 0.5);
	off *= heat_rise;
	vec4 c = mix(from_clamped(uv + off), to_clamped(uv + off * 1.2), w);
	vec3 rgb = c.rgb * mix(vec3(1.0), vec3(1.08, 1.0, 0.86), warmth * env) + vec3(0.04, 0.02, 0.0) * warmth * env * c.a;
	return vec4(min(rgb, vec3(c.a)), c.a);
}

void fragment() {
	COLOR = transition(UV);
}
