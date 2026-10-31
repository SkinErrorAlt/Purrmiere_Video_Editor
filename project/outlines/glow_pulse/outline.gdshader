shader_type canvas_item;
#include "res://outlines/outline.gdshaderinc"

uniform vec4 colour : source_color = vec4(1.0);
uniform float thickness = 1.0;
uniform float time = 0.0;
uniform float glow = 8.0;
uniform float speed = 1.0;
uniform float strength = 0.8;

void fragment() {
	float d = abs(outline_distance(UV));
	float half_width = thickness * 0.5;
	float line = 1.0 - smoothstep(half_width - 0.5, half_width + 0.5, d);
	float pulse = 0.5 + 0.5 * sin(time * speed * TAU);
	float spread = max(glow, 0.5) * (0.6 + 0.4 * pulse);
	float halo = exp(-(d * d) / (spread * spread)) * clamp(strength, 0.0, 1.0) * (0.4 + 0.6 * pulse);
	COLOR = vec4(colour.rgb, colour.a * max(line, halo));
}
