shader_type canvas_item;
#include "res://outlines/outline.gdshaderinc"

uniform vec4 colour : source_color = vec4(1.0);
uniform float thickness = 1.0;
uniform float arm = 16.0;

void fragment() {
	float d = abs(outline_distance(UV));
	float half_width = thickness * 0.5;
	float line = 1.0 - smoothstep(half_width - 0.5, half_width + 0.5, d);
	float keep = 1.0 - smoothstep(arm - 0.5, arm + 0.5, outline_corner(UV));
	COLOR = vec4(colour.rgb, colour.a * line * keep);
}
