uniform float hold = 1.2;
uniform float clean = 0.0;
uniform float start = 0.0;
uniform float block = 16.0;
uniform float clip_time = 0.0;
uniform float px_scale = 1.0;

const int TILES = 8;

int mosh_age() {
	float fps = max(history_fps, 1.0);
	float t = clip_time - start;
	if (t < -0.0001) {
		return 0;
	}
	int n = int(floor(t * fps + 0.0001));
	int hold_f = clamp(int(round(hold * fps)), 2, 62);
	int clean_f = max(int(round(clean * fps)), 0);
	int cycle = hold_f + clean_f;
	int p = n % cycle;
	if (p < clean_f) {
		return 0;
	}
	return min(p - clean_f, history_count);
}

float block_px(vec2 size) {
	float tile_w = floor(size.x / float(TILES));
	float tile_h = floor(size.y / float(TILES));
	float need = max(size.x / max(tile_w, 1.0), size.y / max(tile_h, 1.0));
	return max(block * px_scale, ceil(need));
}

float mv_range() {
	return 48.0 * max(px_scale, 0.05);
}
