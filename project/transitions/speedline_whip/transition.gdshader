shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform vec2 center = vec2(0.5, 0.5);
uniform float lines : hint_range(30.0, 300.0) = 130.0;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float zoom : hint_range(0.0, 1.0) = 0.5;

vec4 transition(vec2 uv) {
	float e = clamp(progress, 0.0, 1.0);
	float peak = sin(e * TR_PI);
	vec2 q = (uv - center) * vec2(tr_ratio(), 1.0);
	float ang = atan(q.y, q.x);
	float rad = length(q);

	float za = 1.0 + e * zoom * 0.8;
	float zb = 1.0 + (1.0 - e) * zoom * 0.8;
	vec4 a = from_clamped((uv - center) / za + center);
	vec4 b = to_clamped((uv - center) / zb + center);
	float m = smoothstep(0.46, 0.54, e);
	vec4 base = mix(a, b, m);

	float ln = abs(fract(ang / (2.0 * TR_PI) * lines) - 0.5) * 2.0;
	float jitter = tr_hash(vec2(floor(ang / (2.0 * TR_PI) * lines), 1.0));
	float sl = smoothstep(0.65, 0.95, ln) * smoothstep(0.08, 0.5, rad) * peak * (0.6 + 0.6 * jitter);
	base.rgb = mix(base.rgb, line_color.rgb, clamp(sl * line_color.a, 0.0, 1.0));
	return base;
}

void fragment() {
	COLOR = transition(UV);
}
