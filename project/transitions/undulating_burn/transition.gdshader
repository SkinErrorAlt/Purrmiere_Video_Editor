shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform vec2 centre = vec2(0.5, 0.5);
uniform float smoothness : hint_range(0.002, 0.2) = 0.03;
uniform float waviness : hint_range(0.0, 1.0) = 0.6;
uniform float burn_width : hint_range(0.0, 0.3) = 0.08;
uniform vec4 colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float glow : hint_range(0.0, 2.0) = 0.0;
uniform vec4 glow_colour : source_color = vec4(1.0, 0.45, 0.05, 1.0);

vec4 transition(vec2 uv) {
	float p = progress;
	vec2 c = tr_world(centre);
	vec2 rel = tr_world(uv) - c;
	vec2 h = vec2(tr_ratio() * 0.5, 0.5);
	float reach = length(abs(c) + h);
	float d = length(rel);
	float wave_amp = waviness * 0.16;
	float margin = wave_amp + burn_width + smoothness * 2.0;
	float r = mix(-margin, reach + margin, p);
	vec2 dir = d > 0.000001 ? rel / d : vec2(1.0, 0.0);
	float drift = p * 2.2;
	float n = tr_fbm(dir * 1.8 + rel * 2.5 + vec2(drift, -drift * 0.7));
	float grow = clamp(0.35 + max(r, 0.0) / reach, 0.0, 1.0);
	float e = r + (n - 0.5) * 2.0 * wave_amp * grow;
	float m = 1.0 - smoothstep(e - smoothness, e + smoothness, d);
	vec4 base = mix(from_at(uv), to_at(uv), m);
	float out_side = d - e;
	float band = burn_width > 0.0 ? 1.0 - smoothstep(0.0, burn_width, out_side) : 0.0;
	band *= smoothstep(-smoothness, smoothness, out_side);
	vec4 burnt = vec4(colour.rgb * colour.a, colour.a) * base.a;
	vec4 col = mix(base, burnt, band * (1.0 - m) * colour.a);
	float g = glow * band * band * (1.0 - m);
	col.rgb += glow_colour.rgb * glow_colour.a * g * col.a;
	return col;
}

void fragment() {
	COLOR = transition(UV);
}
