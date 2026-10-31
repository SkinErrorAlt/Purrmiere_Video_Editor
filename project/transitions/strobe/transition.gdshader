shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int flashes : hint_range(1, 12) = 4;
uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_length : hint_range(0.1, 2.0) = 0.6;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform bool alternate = true;

vec4 transition(vec2 uv) {
	int n = clamp(flashes, 1, 12);
	float units = float(n + 1) + float(n) * flash_length;
	float x = clamp(progress, 0.0, 1.0) * units;
	int slot = n;
	bool in_flash = false;
	float edge = 0.0;
	for (int j = 0; j <= 12; j++) {
		if (j > n) {
			break;
		}
		edge += 1.0;
		if (x < edge || j == n) {
			slot = j;
			break;
		}
		edge += flash_length;
		if (x < edge) {
			slot = j;
			in_flash = true;
			break;
		}
	}
	bool show_to;
	if (alternate) {
		show_to = slot > 0 && (n - slot) % 2 == 0;
	} else {
		show_to = slot * 2 >= n + 1 || slot == n;
	}
	if (slot == 0 && !in_flash) {
		show_to = false;
	}
	vec4 pic = show_to ? to_at(uv) : from_at(uv);
	if (in_flash) {
		vec4 c = vec4(colour.rgb * colour.a, colour.a);
		vec4 lifted = vec4(min(pic.rgb * 2.5 + vec3(0.2) * pic.a, vec3(pic.a)), pic.a);
		return mix(lifted, c, strength);
	}
	return pic;
}

void fragment() {
	COLOR = transition(UV);
}
