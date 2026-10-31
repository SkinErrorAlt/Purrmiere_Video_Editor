shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int across = 2;
uniform int down = 1;
uniform float zoom_out : hint_range(1.0, 6.0) = 3.0;
uniform float gap : hint_range(0.0, 40.0) = 0.0;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec4 transition(vec2 uv) {
	vec2 target = vec2(float(across), float(down));
	float lift = sin(progress * TR_PI);
	float z = 1.0 + (max(zoom_out, 1.0) - 1.0) * lift * lift;
	float glide = 0.5 - 0.5 * cos(progress * TR_PI);
	vec2 rp = (uv - 0.5) * z + 0.5 + target * glide;
	vec2 tile = floor(rp);
	vec2 cell_uv = rp - tile;
	bool at_start = tile.x == 0.0 && tile.y == 0.0;
	bool at_end = tile.x == target.x && tile.y == target.y;
	float pick = tr_hash(tile + vec2(0.37, 0.71));
	float turn_pick = tr_hash(tile + vec2(5.3, 1.9));
	vec2 suv = cell_uv;
	if (!at_start && !at_end) {
		if (turn_pick > 0.5) {
			suv.x = 1.0 - suv.x;
		}
		if (fract(turn_pick * 7.0) > 0.5) {
			suv.y = 1.0 - suv.y;
		}
	}
	bool show_to = at_end || (!at_start && pick > 0.5);
	vec4 col = show_to ? to_clamped(suv) : from_clamped(suv);
	if (at_start && at_end) {
		col = mix(from_clamped(suv), to_clamped(suv), smoothstep(0.3, 0.7, progress));
	}
	float gz = (z - 1.0) / max(max(zoom_out, 1.0) - 1.0, 0.0001);
	float gw = gap * px_scale * gz;
	vec2 edge_px = min(cell_uv, 1.0 - cell_uv) * frame_px / z;
	float inside = clamp(min(edge_px.x, edge_px.y) - gw * 0.5 + 0.5, 0.0, 1.0);
	if (gw <= 0.0) {
		inside = 1.0;
	}
	vec4 bg = vec4(background.rgb * background.a, background.a);
	return mix(bg, col, inside);
}

void fragment() {
	COLOR = transition(UV);
}
