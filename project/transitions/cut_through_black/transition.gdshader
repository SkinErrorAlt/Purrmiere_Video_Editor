shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform vec4 colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float hold : hint_range(0.1, 0.9) = 0.5;
uniform float balance : hint_range(0.1, 0.9) = 0.5;
uniform float edge : hint_range(0.0, 0.2) = 0.0;

vec4 transition(vec2 uv) {
	vec4 c = vec4(colour.rgb * colour.a, colour.a);
	float t1 = balance * (1.0 - hold);
	float t2 = t1 + hold;
	float e = max(edge, 0.0006);
	float to_colour = smoothstep(t1 - e, t1 + e, progress);
	float to_incoming = smoothstep(t2 - e, t2 + e, progress);
	vec4 a = mix(from_at(uv), c, to_colour);
	return mix(a, to_at(uv), to_incoming);
}

void fragment() {
	COLOR = transition(UV);
}
