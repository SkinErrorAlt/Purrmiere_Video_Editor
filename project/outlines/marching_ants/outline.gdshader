shader_type canvas_item;
#include "res://outlines/outline.gdshaderinc"

uniform vec4 colour : source_color = vec4(1.0);
uniform float thickness = 1.0;
uniform float time = 0.0;
uniform float dash = 6.0;
uniform float speed = 24.0;

void fragment() {
	float d = abs(outline_distance(UV));
	float half_width = thickness * 0.5;
	float line = 1.0 - smoothstep(half_width - 0.5, half_width + 0.5, d);
	float period = max(dash * 2.0, 2.0);
	float at = mod(outline_along(UV) - time * speed, period);
	float light = 1.0 - smoothstep(dash - 0.5, dash + 0.5, at);
	float lum = dot(colour.rgb, vec3(0.299, 0.587, 0.114));
	vec3 other = lum > 0.5 ? vec3(0.0) : vec3(1.0);
	COLOR = vec4(mix(other, colour.rgb, light), colour.a * line);
}
