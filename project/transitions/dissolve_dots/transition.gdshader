shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float grain : hint_range(1.0, 64.0) = 8.0;
uniform float softness : hint_range(0.0, 1.0) = 0.0;
uniform int shape = 0;

vec4 transition(vec2 uv) {
	float size = max(grain * px_scale, 0.5);
	vec2 cell_pos = uv * frame_px / size;
	vec2 cell = floor(cell_pos);
	float h = tr_hash(cell + vec2(3.7, 11.3)) * 0.998 + 0.001;
	float span = shape == 1 ? max(softness, 0.2) : max(softness, 0.0005);
	float tc = clamp((progress - h * (1.0 - span)) / span, 0.0, 1.0);
	float w = tc;
	if (shape == 1) {
		float aa = 1.0 / size;
		float r = tc * (0.7072 + aa);
		float d = length(fract(cell_pos) - 0.5);
		w = 1.0 - smoothstep(r - aa, r, d);
		w = progress >= 1.0 ? 1.0 : w;
	}
	return mix(from_at(uv), to_at(uv), w);
}

void fragment() {
	COLOR = transition(UV);
}
