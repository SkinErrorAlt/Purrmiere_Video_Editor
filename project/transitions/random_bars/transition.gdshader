shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int orientation = 0;
uniform int bars : hint_range(4, 600) = 200;
uniform float fade : hint_range(0.0, 1.0) = 0.06;

vec4 transition(vec2 uv) {
	float c = orientation == 0 ? uv.x : uv.y;
	float n = float(max(bars, 1));
	float idx = min(floor(c * n), n - 1.0);
	float h = tr_hash(vec2(idx + 0.5, 17.0 + float(orientation) * 31.0));
	float f = max(fade, 0.0001);
	float start = h * (1.0 - f);
	float m = smoothstep(start, start + f, progress);
	return mix(from_at(uv), to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}
