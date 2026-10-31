shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int order : hint_range(0, 5) = 0;
uniform int columns : hint_range(1, 64) = 10;
uniform int rows : hint_range(1, 64) = 6;
uniform float fade : hint_range(0.0, 0.5) = 0.03;
uniform int seed : hint_range(0, 9999) = 0;

float h(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	int W = max(columns, 1);
	int H = max(rows, 1);
	int cx = clamp(int(floor(UV.x * float(W))), 0, W - 1);
	int cy = clamp(int(floor(UV.y * float(H))), 0, H - 1);
	int N = W * H;
	float t;
	if (order <= 1) {
		int r = min(min(cx, cy), min(W - 1 - cx, H - 1 - cy));
		int w = W - 2 * r;
		int hh = H - 2 * r;
		int before = N - w * hh;
		int x = cx - r;
		int y = cy - r;
		int pos;
		if (w == 1 || hh == 1) {
			pos = x + y;
		} else if (y == 0) {
			pos = x;
		} else if (x == w - 1) {
			pos = (w - 1) + y;
		} else if (y == hh - 1) {
			pos = (w - 1) + (hh - 1) + (w - 1 - x);
		} else {
			pos = 2 * (w - 1) + (hh - 1) + (hh - 1 - y);
		}
		int k = before + pos;
		if (order == 1) { k = N - 1 - k; }
		t = (float(k) + 0.5) / float(N);
	} else if (order == 2) {
		t = (float(cy * W + ((cy % 2 == 1) ? W - 1 - cx : cx)) + 0.5) / float(N);
	} else if (order == 3) {
		t = (float(cx * H + ((cx % 2 == 1) ? H - 1 - cy : cy)) + 0.5) / float(N);
	} else if (order == 4) {
		t = h(vec3(float(cx), float(cy), float(seed)));
	} else {
		t = (float(cx) + 0.5) / float(W) * 0.7 + h(vec3(float(cx), float(cy), float(seed))) * 0.3;
	}
	float fd = max(fade, 0.0001);
	float ts = t * (1.0 - fd);
	COLOR = c * (1.0 - smoothstep(ts, ts + fd, progress));
}
