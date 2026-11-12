shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int cols : hint_range(2, 40) = 10;
uniform int rows : hint_range(2, 24) = 6;
uniform int way : hint_range(0, 1) = 0;
uniform int turn : hint_range(0, 1) = 0;
uniform float overlap : hint_range(0.0, 0.9) = 0.1;
uniform int curve = 0;

int spiral_order(int cx, int cy, int w, int h) {
	int r = min(min(cx, cy), min(w - 1 - cx, h - 1 - cy));
	int iw = w - 2 * r;
	int ih = h - 2 * r;
	int before = w * h - iw * ih;
	int lx = cx - r;
	int ly = cy - r;
	int idx = 0;
	if (ly == 0) {
		idx = lx;
	} else if (lx == iw - 1) {
		idx = iw - 1 + ly;
	} else if (ly == ih - 1) {
		idx = iw - 1 + ih - 1 + (iw - 1 - lx);
	} else {
		idx = 2 * (iw - 1) + ih - 1 + (ih - 1 - ly);
	}
	return before + idx;
}

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	int w = max(cols, 2);
	int h = max(rows, 2);
	int cx = clamp(int(floor(uv.x * float(w))), 0, w - 1);
	int cy = clamp(int(floor(uv.y * float(h))), 0, h - 1);
	int sx = turn == 1 ? w - 1 - cx : cx;
	int order = spiral_order(sx, cy, w, h);
	int total = w * h;
	if (way == 1) {
		order = total - 1 - order;
	}
	float f = float(order) / float(max(total - 1, 1));
	float span = clamp(max(overlap, 1.0 / float(max(total, 1))), 0.0005, 1.0);
	float start = f * (1.0 - span);
	float m = clamp((p - start) / span, 0.0, 1.0);
	m = m * m * (3.0 - 2.0 * m);
	return mix(from_at(uv), to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}
