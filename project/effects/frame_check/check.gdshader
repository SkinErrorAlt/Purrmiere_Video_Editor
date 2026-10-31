shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float time = 0.0;
uniform float clip_time = 0.0;
uniform float seq_fps = 30.0;
uniform int count = 0;
uniform int rate = 0;
uniform int place = 0;
uniform float size : hint_range(0.5, 2.0) = 1.0;
uniform float backdrop : hint_range(0.0, 1.0) = 0.9;
uniform vec4 lamp_colour : source_color = vec4(0.3, 1.0, 0.45, 1.0);

const int SEGS[10] = int[10](63, 6, 91, 79, 102, 109, 125, 7, 127, 111);
const float GLYPH_W = 0.5;
const float BAR = 0.08;
const float GAP = 0.016;
const float CELL = 0.66;

float bar_across(vec2 p, vec2 m, float half_len) {
	vec2 q = abs(p - m);
	return max(q.y - BAR, (q.x + q.y - half_len) * 0.7071);
}

float bar_down(vec2 p, vec2 m, float half_len) {
	vec2 q = abs(p - m);
	return max(q.x - BAR, (q.y + q.x - half_len) * 0.7071);
}

float seven(vec2 p, int mask) {
	float across = GLYPH_W * 0.5 - BAR - GAP;
	float down = (0.5 - BAR) * 0.5 - GAP;
	float upper = (BAR + 0.5) * 0.5;
	float lower = (0.5 + 1.0 - BAR) * 0.5;
	float left = BAR;
	float right = GLYPH_W - BAR;
	float mid = GLYPH_W * 0.5;
	float d = 100000.0;
	if ((mask & 1) != 0) { d = min(d, bar_across(p, vec2(mid, BAR), across)); }
	if ((mask & 2) != 0) { d = min(d, bar_down(p, vec2(right, upper), down)); }
	if ((mask & 4) != 0) { d = min(d, bar_down(p, vec2(right, lower), down)); }
	if ((mask & 8) != 0) { d = min(d, bar_across(p, vec2(mid, 1.0 - BAR), across)); }
	if ((mask & 16) != 0) { d = min(d, bar_down(p, vec2(left, lower), down)); }
	if ((mask & 32) != 0) { d = min(d, bar_down(p, vec2(left, upper), down)); }
	if ((mask & 64) != 0) { d = min(d, bar_across(p, vec2(mid, 0.5), across)); }
	return d;
}

float rate_of(int r) {
	if (r == 1) { return 24000.0 / 1001.0; }
	if (r == 2) { return 24.0; }
	if (r == 3) { return 25.0; }
	if (r == 4) { return 30000.0 / 1001.0; }
	if (r == 5) { return 30.0; }
	if (r == 6) { return 50.0; }
	if (r == 7) { return 60000.0 / 1001.0; }
	if (r == 8) { return 60.0; }
	if (r == 9) { return 120.0; }
	return max(seq_fps, 1.0);
}

float box_sd(vec2 p, vec2 b) {
	vec2 q = abs(p) - b;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
}

vec4 over(vec4 top, vec4 under) {
	return top + under * (1.0 - top.a);
}

void fragment() {
	vec4 pic = texture(TEXTURE, UV);
	float asp = max(tex_size.x, 1.0) / max(tex_size.y, 1.0);
	vec2 q = UV * vec2(asp, 1.0);
	float aa = max(length(fwidth(q)) * 0.7071, 0.000001);
	float fps = rate_of(rate);
	float t = count == 1 ? clip_time : time;
	int frame = int(floor(max(t, 0.0) * fps + 0.001));
	int per_second = max(int(round(fps)), 1);
	float sz = clamp(size, 0.5, 2.0) * min(1.0, asp / 1.2);
	float panel_h = 0.28 * sz;
	float top = place == 0 ? 1.0 - panel_h : 0.0;
	float in_panel = step(top, q.y) * step(q.y, top + panel_h);
	vec4 c = pic;
	c = over(vec4(0.0, 0.0, 0.0, clamp(backdrop, 0.0, 1.0) * in_panel), c);
	vec3 lamp = lamp_colour.rgb;
	float pad = 0.025 * sz;
	float digit_h = 0.1 * sz;
	vec2 origin = vec2(pad, top + pad);
	float gx = (q.x - origin.x) / digit_h;
	float gy = (q.y - origin.y) / digit_h;
	float num_cov = 0.0;
	if (gy >= -0.1 && gy <= 1.1 && gx >= 0.0 && gx < CELL * 6.0) {
		int cell_i = int(floor(gx / CELL));
		int place_v = 5 - cell_i;
		int v = frame;
		for (int i = 0; i < 6; i++) {
			if (i >= place_v) {
				break;
			}
			v = v / 10;
		}
		int dgt = v % 10;
		vec2 gp = vec2(gx - float(cell_i) * CELL - 0.08, gy);
		float d = seven(gp, SEGS[dgt]) * digit_h;
		num_cov = clamp(0.5 - d / aa, 0.0, 1.0);
	}
	c = over(vec4(vec3(1.0), 1.0) * num_cov, c);
	float flash_x = origin.x + CELL * 6.0 * digit_h + pad;
	vec2 fc = vec2(flash_x + digit_h * 0.5, origin.y + digit_h * 0.5);
	float fd = box_sd(q - fc, vec2(digit_h * 0.5));
	float fcov = clamp(0.5 - fd / aa, 0.0, 1.0);
	bool on_second = frame % per_second == 0;
	c = over(vec4(on_second ? vec3(1.0) : vec3(0.18), 1.0) * fcov, c);
	float strip_y = origin.y + digit_h + pad * 0.8;
	float lamp_h = 0.028 * sz;
	float strip_w = min(asp - pad * 2.0, 0.9 * sz);
	float cell_w = strip_w / 10.0;
	for (int row = 0; row < 2; row++) {
		float y0 = strip_y + float(row) * (lamp_h + pad * 0.5);
		int lit = row == 0 ? frame % 10 : (frame / 10) % 10;
		float lx = (q.x - pad) / cell_w;
		if (lx >= 0.0 && lx < 10.0) {
			int li = int(floor(lx));
			vec2 lc = vec2(pad + (float(li) + 0.5) * cell_w, y0 + lamp_h * 0.5);
			float ld = box_sd(q - lc, vec2(cell_w * 0.4, lamp_h * 0.4));
			float lcov = clamp(0.5 - ld / aa, 0.0, 1.0);
			vec3 col = li == lit ? lamp : lamp * 0.14;
			c = over(vec4(col, 1.0) * lcov, c);
		}
	}
	float sweep_y = strip_y + 2.0 * (lamp_h + pad * 0.5);
	float sweep_h = max(top + panel_h - pad * 0.6 - sweep_y, lamp_h * 0.5);
	float sw_w = asp - pad * 2.0;
	float scell = sw_w / float(per_second);
	float sx = (q.x - pad) / max(scell, 0.00001);
	if (sx >= 0.0 && sx < float(per_second) && q.y >= sweep_y && q.y <= sweep_y + sweep_h) {
		int si = int(floor(sx));
		bool lit_now = si == frame % per_second;
		float edge = fract(sx);
		float gap_k = scell > aa * 3.0 ? smoothstep(0.0, aa / scell, edge) * smoothstep(0.0, aa / scell, 1.0 - edge) : 1.0;
		vec3 col = lit_now ? vec3(1.0) : (si % 2 == 0 ? vec3(0.22) : vec3(0.3));
		c = over(vec4(col, 1.0) * gap_k, c);
	}
	COLOR = c;
}
