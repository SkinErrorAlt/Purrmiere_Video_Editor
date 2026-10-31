shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform vec2 centre = vec2(0.5, 0.5);
uniform float spread : hint_range(0.0, 1.0) = 0.33;
uniform float fade : hint_range(0.01, 0.5) = 0.1;
uniform float line_width : hint_range(1.0, 24.0) = 2.0;

vec4 transition(vec2 uv) {
	float p = progress;
	float lw = max(line_width * px_scale, 1.0);
	vec2 cell = floor(uv * frame_px / lw);
	float row = tr_hash(vec2(cell.y, 0.0) + vec2(0.37, 91.3));
	float col = tr_hash(vec2(0.0, cell.x) + vec2(53.1, 0.71));
	vec2 h = vec2(tr_ratio() * 0.5, 0.5);
	vec2 c = tr_world(centre);
	float reach = length(abs(c) + h);
	float dist = length(tr_world(uv) - c) / reach * spread;
	float r = p - min(row, col);
	float shown = step(dist, r);
	float m = mix(0.0, mix(shown, 1.0, smoothstep(1.0 - fade, 1.0, p)), smoothstep(0.0, fade, p));
	return mix(from_at(uv), to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}
