shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int timing = 1;
uniform float scale : hint_range(2.0, 14.0) = 5.0;
uniform float warp_amt : hint_range(0.0, 1.2) = 0.45;
uniform float feather : hint_range(0.02, 0.3) = 0.12;
uniform float fringe : hint_range(0.0, 1.0) = 0.55;
uniform vec4 ink_tint : source_color = vec4(0.08, 0.04, 0.07, 1.0);

int curve_of(int t) {
	if (t == 1) { return 3; }
	else if (t == 2) { return 4; }
	else if (t == 3) { return 2; }
	else if (t == 4) { return 5; }
	else if (t == 5) { return 7; }
	return 0;
}

vec4 transition(vec2 uv) {
	float e = tr_ease(progress, curve_of(timing));
	vec2 w = vec2(tr_fbm(uv * scale + vec2(1.3, 4.7)), tr_fbm(uv * scale + vec2(9.1, 2.2)));
	vec2 duv = uv + (w - 0.5) * warp_amt;
	float billow = tr_fbm(duv * scale) * 0.55;

	float d = length((uv - vec2(0.5)) * vec2(tr_ratio(), 1.0)) / (0.72 * max(tr_ratio(), 1.0));
	float field = (1.0 - d) + billow - 0.3;

	float t2 = mix(1.25, -0.25, e);
	float m = smoothstep(t2 - feather, t2 + feather, field);

	vec4 a = from_at(uv);
	vec4 b = to_at(uv);
	vec4 base = mix(a, b, m);

	float front = 1.0 - abs(m - 0.5) * 2.0;
	float f = clamp(front, 0.0, 1.0) * fringe;
	vec3 tinted = mix(base.rgb, ink_tint.rgb * max(base.a, 0.001), f);
	return vec4(tinted, base.a);
}

void fragment() {
	COLOR = transition(UV);
}
