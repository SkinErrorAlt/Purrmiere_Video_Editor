shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float fold : hint_range(0.1, 0.9) = 0.5;
uniform float fingers : hint_range(0.0, 1.0) = 0.6;
uniform float islands : hint_range(0.0, 1.0) = 0.45;
uniform float rim : hint_range(0.0, 1.0) = 0.5;
uniform int lie : hint_range(0, 1) = 0;

float blot_field(vec2 q) {
	float r = length(q);
	float a = atan(q.y, q.x);
	float lobes = tr_fbm(vec2(cos(a), sin(a)) * 2.6 + 4.0) - 0.5;
	float fine = tr_fbm(q * 7.0 + 9.0) - 0.5;
	return r * (1.0 - lobes * 1.3 * fingers - fine * 0.55 * fingers);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float ar = tr_ratio();
	vec2 o = lie == 1 ? vec2(uv.y, uv.x) : uv;
	float scale_x = lie == 1 ? 1.0 : ar;
	float scale_y = lie == 1 ? ar : 1.0;
	vec2 mid = vec2(fold, 0.5);
	vec2 d = vec2((o.x - mid.x) * scale_x, (o.y - mid.y) * scale_y);
	vec2 q = vec2(abs(d.x), d.y);
	float f = blot_field(q);
	float reach = 1.35;
	float edge = p * reach;
	float soft = 0.012;
	float m = 1.0 - smoothstep(edge - soft, edge + soft, f);
	float island = 0.0;
	if (islands > 0.0) {
		vec2 g = floor(q * 9.0);
		vec2 h = tr_hash2(g + 12.0);
		vec2 at = (g + 0.2 + h * 0.6) / 9.0;
		float ir = (0.012 + h.x * 0.028) * islands;
		float dd = length(q - at);
		float born = step(0.55, tr_hash(g + 31.0));
		island = born * (1.0 - smoothstep(ir, ir + 0.006, dd)) * step(length(at), edge + 0.16) * step(edge, length(at) + 0.2);
	}
	m = max(m, island);
	m = max(m, smoothstep(0.94, 1.0, p));
	vec4 col = mix(from_at(uv), to_at(uv), m);
	float wet = smoothstep(0.055, 0.0, abs(f - edge)) * rim * m * (1.0 - smoothstep(0.9, 1.0, p));
	col.rgb *= 1.0 - wet * 0.55;
	return col;
}

void fragment() {
	COLOR = transition(UV);
}
