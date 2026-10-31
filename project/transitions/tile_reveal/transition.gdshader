shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int tiles = 10;
uniform int order = 0;
uniform int axis = 0;
uniform float stagger : hint_range(0.0, 0.95) = 0.7;
uniform float shading : hint_range(0.0, 1.0) = 0.5;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec4 transition(vec2 uv) {
	float n = float(max(tiles, 1));
	float ratio = tr_ratio();
	float rows = max(floor(n / ratio + 0.5), 1.0);
	vec2 grid = vec2(n, rows);
	vec2 q = uv * grid;
	vec2 id = floor(q);
	vec2 gv = fract(q) - 0.5;
	vec2 cuv = (id + 0.5) / grid;
	float o = tr_hash(id + vec2(0.5));
	if (order == 1) {
		o = cuv.x;
	} else if (order == 2) {
		o = (cuv.x + cuv.y) * 0.5;
	} else if (order == 3) {
		o = length(tr_world(cuv)) / (0.5 * sqrt(ratio * ratio + 1.0));
	}
	float st = clamp(stagger, 0.0, 0.95);
	float lp = clamp((progress - clamp(o, 0.0, 1.0) * st) / (1.0 - st), 0.0, 1.0);
	lp = tr_ease(lp, 3);
	float sc = abs(cos(lp * TR_PI));
	bool back = lp > 0.5;
	float g = axis == 0 ? gv.x : gv.y;
	float tile_px = axis == 0 ? frame_px.x / grid.x : frame_px.y / grid.y;
	float hw = 0.5 * sc;
	float cov = clamp((hw - abs(g)) * tile_px + 1.0, 0.0, 1.0);
	vec2 src = gv;
	if (axis == 0) {
		src.x = gv.x / max(sc, 0.0001);
	} else {
		src.y = gv.y / max(sc, 0.0001);
	}
	vec2 suv = (id + 0.5 + clamp(src, -0.5, 0.5)) / grid;
	vec4 pic = back ? to_clamped(suv) : from_clamped(suv);
	if (sc >= 1.0) {
		pic = back ? to_at(uv) : from_at(uv);
	}
	float light = 1.0 - shading * 0.6 * (1.0 - sc);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	return mix(bg, tr_shade(pic, light), cov);
}

void fragment() {
	COLOR = transition(UV);
}
