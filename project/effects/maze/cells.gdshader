shader_type canvas_item;
render_mode blend_disabled;

uniform float passage : hint_range(2.0, 200.0) = 10.0;
uniform float wall : hint_range(1.0, 200.0) = 10.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

const int SIDE = 16;
const int JAG = 3;
const int WIN = 22;

uint mixbits(uint x) {
	x ^= x >> 16u;
	x *= 2146121005u;
	x ^= x >> 15u;
	x *= 2221713035u;
	x ^= x >> 16u;
	return x;
}

uint hash4(int a, int b, int c, int d) {
	uint h = mixbits(uint(seed) * 2654435761u + 374761393u);
	h = mixbits(h ^ (uint(a) * 2246822519u));
	h = mixbits(h ^ (uint(b) * 3266489917u));
	h = mixbits(h ^ (uint(c) * 668265263u));
	h = mixbits(h ^ (uint(d) * 374761393u));
	return h;
}

float lattice(int key, int i) {
	return float(hash4(71, key, i, 5) & 65535u) / 32767.5 - 1.0;
}

float wobble(int key, int t) {
	float x = float(t) / 12.0;
	int i = int(floor(x));
	float f = x - float(i);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(lattice(key, i), lattice(key, i + 1), u);
}

int jag(int axis, int k, int t, int limit) {
	if (k <= 0 || k * SIDE + JAG >= limit - 1) {
		return 0;
	}
	return int(round(float(JAG) * wobble(axis * 4099 + k, t)));
}

ivec2 block_of(ivec2 p, ivec2 cells) {
	int kx = p.x / SIDE;
	int bx = kx - 1;
	if (p.x >= (kx + 1) * SIDE + jag(0, kx + 1, p.y, cells.x)) {
		bx = kx + 1;
	} else if (p.x >= kx * SIDE + jag(0, kx, p.y, cells.x)) {
		bx = kx;
	}
	int ky = p.y / SIDE;
	int by = ky - 1;
	if (p.y >= (ky + 1) * SIDE + jag(1, ky + 1, p.x, cells.y)) {
		by = ky + 1;
	} else if (p.y >= ky * SIDE + jag(1, ky, p.x, cells.y)) {
		by = ky;
	}
	return ivec2(bx, by);
}

bool in_maze(ivec2 p, ivec2 cells) {
	return p.x >= 0 && p.y >= 0 && p.x < cells.x && p.y < cells.y;
}

bool member(ivec2 p, ivec2 b, ivec2 cells) {
	return in_maze(p, cells) && block_of(p, cells) == b;
}

bvec2 cell_edges(ivec2 b, ivec2 cells, int n, int m, int o) {
	ivec2 origin = b * SIDE - JAG;
	int lo_x[22];
	int hi_x[22];
	int lo_y[22];
	int hi_y[22];
	for (int t = 0; t < WIN; t++) {
		int y = origin.y + t;
		int x = origin.x + t;
		lo_x[t] = max(b.x * SIDE + jag(0, b.x, y, cells.x), 0);
		hi_x[t] = min((b.x + 1) * SIDE + jag(0, b.x + 1, y, cells.x), cells.x);
		lo_y[t] = max(b.y * SIDE + jag(1, b.y, x, cells.y), 0);
		hi_y[t] = min((b.y + 1) * SIDE + jag(1, b.y + 1, x, cells.y), cells.y);
		if (y < 0 || y >= cells.y) {
			hi_x[t] = lo_x[t];
		}
		if (x < 0 || x >= cells.x) {
			hi_y[t] = lo_y[t];
		}
	}
	uint seen[16];
	for (int k = 0; k < 16; k++) {
		seen[k] = 0u;
	}
	int stack[484];
	ivec2 s = clamp(b * SIDE + SIDE / 2, ivec2(0), cells - 1) - origin;
	int start = s.y * WIN + s.x;
	seen[start >> 5] |= 1u << uint(start & 31);
	stack[0] = start;
	int sp = 1;
	bool got_n = start == n;
	bool got_m = m < 0 || start == m;
	bool got_o = o < 0 || start == o;
	int parent_n = -1;
	int parent_m = -1;
	int parent_o = -1;
	for (int it = 0; it < 980; it++) {
		if (sp <= 0 || (got_n && got_m && got_o)) {
			break;
		}
		int cur = stack[sp - 1];
		int cx = cur % WIN;
		int cy = cur / WIN;
		int opts[4];
		int cnt = 0;
		for (int d = 0; d < 4; d++) {
			ivec2 step_d = d == 0 ? ivec2(-1, 0) : (d == 1 ? ivec2(1, 0) : (d == 2 ? ivec2(0, -1) : ivec2(0, 1)));
			int nx = cx + step_d.x;
			int ny = cy + step_d.y;
			if (nx < 0 || ny < 0 || nx >= WIN || ny >= WIN) {
				continue;
			}
			int nb = ny * WIN + nx;
			if ((seen[nb >> 5] & (1u << uint(nb & 31))) != 0u) {
				continue;
			}
			int ax = origin.x + nx;
			int ay = origin.y + ny;
			if (ax < lo_x[ny] || ax >= hi_x[ny] || ay < lo_y[nx] || ay >= hi_y[nx]) {
				continue;
			}
			opts[cnt] = nb;
			cnt++;
		}
		if (cnt == 0) {
			sp--;
			continue;
		}
		int nxt = opts[int(hash4(0, b.x * 131 + b.y, cur, it) % uint(cnt))];
		seen[nxt >> 5] |= 1u << uint(nxt & 31);
		stack[sp] = nxt;
		sp++;
		if (nxt == n) {
			got_n = true;
			parent_n = cur;
		}
		if (nxt == m) {
			got_m = true;
			parent_m = cur;
		}
		if (nxt == o) {
			got_o = true;
			parent_o = cur;
		}
	}
	return bvec2(m >= 0 && (parent_n == m || parent_m == n), o >= 0 && (parent_n == o || parent_o == n));
}

bool grid_edge(int lvl, ivec2 group, ivec2 dims, int n, int m) {
	uint seen[8];
	for (int k = 0; k < 8; k++) {
		seen[k] = 0u;
	}
	int stack[256];
	int sx = int(hash4(lvl, group.x, group.y, 11) % uint(max(dims.x, 1)));
	int sy = int(hash4(lvl, group.x, group.y, 13) % uint(max(dims.y, 1)));
	int start = sy * SIDE + sx;
	seen[start >> 5] |= 1u << uint(start & 31);
	stack[0] = start;
	int sp = 1;
	bool got_n = start == n;
	bool got_m = start == m;
	int parent_n = -1;
	int parent_m = -1;
	for (int it = 0; it < 520; it++) {
		if (sp <= 0 || (got_n && got_m)) {
			break;
		}
		int cur = stack[sp - 1];
		int cx = cur % SIDE;
		int cy = cur / SIDE;
		int opts[4];
		int cnt = 0;
		int nb = cur - 1;
		if (cx > 0 && (seen[nb >> 5] & (1u << uint(nb & 31))) == 0u) {
			opts[cnt] = nb;
			cnt++;
		}
		nb = cur + 1;
		if (cx + 1 < dims.x && (seen[nb >> 5] & (1u << uint(nb & 31))) == 0u) {
			opts[cnt] = nb;
			cnt++;
		}
		nb = cur - SIDE;
		if (cy > 0 && (seen[nb >> 5] & (1u << uint(nb & 31))) == 0u) {
			opts[cnt] = nb;
			cnt++;
		}
		nb = cur + SIDE;
		if (cy + 1 < dims.y && (seen[nb >> 5] & (1u << uint(nb & 31))) == 0u) {
			opts[cnt] = nb;
			cnt++;
		}
		if (cnt == 0) {
			sp--;
			continue;
		}
		int nxt = opts[int(hash4(lvl, group.x * 131 + group.y, cur, it) % uint(cnt))];
		seen[nxt >> 5] |= 1u << uint(nxt & 31);
		stack[sp] = nxt;
		sp++;
		if (nxt == n) {
			got_n = true;
			parent_n = cur;
		}
		if (nxt == m) {
			got_m = true;
			parent_m = cur;
		}
	}
	return parent_n == m || parent_m == n;
}

int grid_index(ivec2 p) {
	return (p.y % SIDE) * SIDE + (p.x % SIDE);
}

ivec2 opening(ivec2 a, ivec2 d, ivec2 cells) {
	ivec2 b = a + d;
	int count = 0;
	for (int t = 0; t < WIN; t++) {
		ivec2 far_side;
		if (d.x == 1) {
			int y = a.y * SIDE - JAG + t;
			far_side = ivec2(b.x * SIDE + jag(0, b.x, y, cells.x), y);
		} else {
			int x = a.x * SIDE - JAG + t;
			far_side = ivec2(x, b.y * SIDE + jag(1, b.y, x, cells.y));
		}
		if (member(far_side - d, a, cells) && member(far_side, b, cells)) {
			count++;
		}
	}
	if (count == 0) {
		return ivec2(-9);
	}
	int want = int(hash4(21, a.x, a.y, d.x * 2 + d.y) % uint(count));
	for (int t = 0; t < WIN; t++) {
		ivec2 far_side;
		if (d.x == 1) {
			int y = a.y * SIDE - JAG + t;
			far_side = ivec2(b.x * SIDE + jag(0, b.x, y, cells.x), y);
		} else {
			int x = a.x * SIDE - JAG + t;
			far_side = ivec2(x, b.y * SIDE + jag(1, b.y, x, cells.y));
		}
		if (member(far_side - d, a, cells) && member(far_side, b, cells)) {
			if (want == 0) {
				return far_side - d;
			}
			want--;
		}
	}
	return ivec2(-9);
}

bool blocks_joined(ivec2 a, ivec2 d, ivec2 cells) {
	ivec2 b = a + d;
	ivec2 blocks = (cells + SIDE - 1) / SIDE;
	ivec2 sa = a / SIDE;
	ivec2 sb = b / SIDE;
	if (sa == sb) {
		return grid_edge(1, sa, min(blocks - sa * SIDE, ivec2(SIDE)), grid_index(a), grid_index(b));
	}
	ivec2 supers = (blocks + SIDE - 1) / SIDE;
	if (!grid_edge(2, ivec2(0), min(supers, ivec2(SIDE)), grid_index(sa), grid_index(sb))) {
		return false;
	}
	int along = d.x == 1 ? a.y : a.x;
	int span = d.x == 1 ? blocks.y - sa.y * SIDE : blocks.x - sa.x * SIDE;
	return along % SIDE == int(hash4(31, sa.x, sa.y, d.x * 2 + d.y) % uint(clamp(span, 1, SIDE)));
}

bool crossing_open(ivec2 p, ivec2 d, ivec2 cells) {
	ivec2 a = block_of(p, cells);
	ivec2 b = block_of(p + d, cells);
	if (b != a + d) {
		return false;
	}
	if (!blocks_joined(a, d, cells)) {
		return false;
	}
	return opening(a, d, cells) == p;
}

void fragment() {
	vec2 layer = max(vec2(textureSize(TEXTURE, 0)), vec2(1.0));
	float q = max(px_scale * layer.x / max(tex_size.x, 1.0), 0.0001);
	float w = max(wall * q, 1.0);
	float pitch = max(passage * q, 1.0) + w;
	ivec2 cells = max(ivec2(floor((layer - w) / pitch)), ivec2(1));
	ivec2 cell = ivec2(floor(UV / SCREEN_PIXEL_SIZE));
	vec2 open_ways = vec2(0.0);
	if (in_maze(cell, cells)) {
		ivec2 b = block_of(cell, cells);
		ivec2 east = cell + ivec2(1, 0);
		ivec2 south = cell + ivec2(0, 1);
		bool has_e = in_maze(east, cells);
		bool has_s = in_maze(south, cells);
		bool inner_e = has_e && block_of(east, cells) == b;
		bool inner_s = has_s && block_of(south, cells) == b;
		if (inner_e || inner_s) {
			ivec2 origin = b * SIDE - JAG;
			ivec2 l = cell - origin;
			int me = l.y * WIN + l.x;
			bvec2 both = cell_edges(b, cells, me, inner_e ? me + 1 : -1, inner_s ? me + WIN : -1);
			open_ways = vec2(both.x ? 1.0 : 0.0, both.y ? 1.0 : 0.0);
		}
		if (has_e && !inner_e && crossing_open(cell, ivec2(1, 0), cells)) {
			open_ways.x = 1.0;
		}
		if (has_s && !inner_s && crossing_open(cell, ivec2(0, 1), cells)) {
			open_ways.y = 1.0;
		}
	}
	COLOR = vec4(open_ways, 0.0, 1.0);
}
