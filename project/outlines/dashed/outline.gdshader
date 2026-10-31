shader_type canvas_item;
#include "res://outlines/outline.gdshaderinc"

uniform vec4 colour : source_color = vec4(1.0);
uniform float thickness = 1.0;
uniform float dash = 8.0;
uniform float gap = 6.0;

void fragment() {
	float d = abs(outline_distance(UV));
	float half_width = thickness * 0.5;
	float line = 1.0 - smoothstep(half_width - 0.5, half_width + 0.5, d);
	float period = max(dash + gap, 1.0);
	float at = mod(outline_along(UV), period);
	float on = smoothstep(-0.5, 0.5, at) * (1.0 - smoothstep(dash - 0.5, dash + 0.5, at));
	COLOR = vec4(colour.rgb, colour.a * line * on);
}
