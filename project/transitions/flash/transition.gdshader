shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_length : hint_range(0.05, 1.0) = 0.6;
uniform float glow : hint_range(0.0, 1.0) = 0.5;

vec4 transition(vec2 uv) {
	float f = 1.0 - clamp(abs(progress - 0.5) / (flash_length * 0.5), 0.0, 1.0);
	float rise = progress < 0.5 ? f * f * (3.0 - 2.0 * f) : 1.0 - pow(1.0 - f, 3.0);
	float i = progress < 0.5 ? pow(f, 2.2) : pow(f, 1.4);
	vec4 base = progress < 0.5 ? from_at(uv) : to_at(uv);
	float lift = 1.0 + glow * 3.0 * rise;
	vec4 bright = vec4(min(base.rgb * lift + vec3(glow * 0.3 * rise) * base.a, vec3(base.a)), base.a);
	vec4 c = vec4(colour.rgb * colour.a, colour.a);
	return mix(bright, c, i);
}

void fragment() {
	COLOR = transition(UV);
}
