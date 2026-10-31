shader_type canvas_item;
#include "res://outlines/outline.gdshaderinc"

uniform vec4 colour : source_color = vec4(1.0);
uniform float thickness = 1.0;
uniform float time = 0.0;
uniform float speed = 0.25;
uniform float bands = 1.0;

vec3 rainbow_hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	float d = abs(outline_distance(UV));
	float half_width = thickness * 0.5;
	float line = 1.0 - smoothstep(half_width - 0.5, half_width + 0.5, d);
	float h = fract(outline_along(UV) / max(outline_perimeter, 1.0) * max(bands, 0.1) - time * speed);
	COLOR = vec4(rainbow_hue(h), colour.a * line);
}
