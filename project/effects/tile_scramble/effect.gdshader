shader_type canvas_item;
render_mode blend_disabled;

uniform int tiles_x : hint_range(1, 64) = 8;
uniform int tiles_y : hint_range(1, 64) = 5;
uniform float shift : hint_range(0.0, 1.0) = 0.3;
uniform int shift_mode : hint_range(0, 1) = 0;
uniform int direction : hint_range(0, 2) = 0;
uniform bool shuffle = false;
uniform int turn : hint_range(0, 2) = 0;
uniform float gap : hint_range(0.0, 40.0) = 2.0;
uniform vec4 gap_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float rate : hint_range(0.0, 30.0) = 0.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float time = 0.0;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec2 mirror_uv(vec2 uv) {
	return vec2(1.0) - abs(vec2(1.0) - mod(uv, vec2(2.0)));
}

int permute(int idx, int n, float key) {
	float bits = ceil(log2(float(max(n, 2))));
	int hb = int(ceil(bits * 0.5));
	int m = 1 << hb;
	int x = idx;
	for (int it = 0; it < 64; it++) {
		int l = x >> hb;
		int r = x & (m - 1);
		for (int k = 0; k < 4; k++) {
			int f = int(h12(vec2(float(r) + 0.5, key + float(k) * 13.71)) * float(m)) & (m - 1);
			int nl = r;
			r = l ^ f;
			l = nl;
		}
		x = l * m + r;
		if (x < n) {
			return x;
		}
	}
	return idx;
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 S = dims / ps;
	ivec2 nt = ivec2(max(tiles_x, 1), max(tiles_y, 1));
	vec2 n = vec2(nt);
	vec2 tile = S / n;
	vec2 g = UV * n;
	vec2 cell = clamp(floor(g), vec2(0.0), n - 1.0);
	vec2 local = g - cell;
	float fs = float(seed);
	vec2 so = vec2(mod(fs * 12.9898, 97.0), mod(fs * 78.233, 91.0));
	float epoch = rate > 0.0 ? floor(time * rate + 0.0001) : 0.0;
	vec2 eo = vec2(mod(epoch * 0.6180339, 1.0) * 613.0, mod(epoch * 0.4142135, 1.0) * 457.0);
	vec2 key = cell + so + eo;
	vec2 src = cell;
	if (shuffle) {
		int idx = int(cell.y) * nt.x + int(cell.x);
		int p = permute(idx, nt.x * nt.y, so.x + eo.x * 1.37 + so.y * 0.11);
		src = vec2(float(p % nt.x), float(p / nt.x));
	}
	float mag = shift_mode == 0 ? shift * h12(key + 3.3) : shift;
	vec2 dir;
	if (direction == 1) {
		dir = vec2(h12(key + 5.1) < 0.5 ? -1.0 : 1.0, 0.0);
	} else if (direction == 2) {
		dir = vec2(0.0, h12(key + 5.1) < 0.5 ? -1.0 : 1.0);
	} else {
		float an = h12(key + 5.1) * 6.2831853;
		dir = vec2(cos(an), sin(an));
	}
	vec2 lp = (local - 0.5) * tile;
	float rot = 0.0;
	if (turn == 1) {
		rot = floor(h12(key + 7.7) * 4.0) * 1.5707963;
	} else if (turn == 2) {
		rot = h12(key + 7.7) * 6.2831853;
	}
	float cr = cos(rot);
	float sr = sin(rot);
	lp = vec2(cr * lp.x - sr * lp.y, sr * lp.x + cr * lp.y);
	vec2 pos = (src + 0.5) * tile + lp + dir * mag * tile;
	vec4 col = texture(TEXTURE, mirror_uv(pos / S));
	float a0 = texture(TEXTURE, UV).a;
	if (gap > 0.0) {
		vec2 ex = vec2(cell.x > 0.0 ? local.x : 9.0, cell.x < n.x - 1.0 ? 1.0 - local.x : 9.0) * tile.x * ps;
		vec2 ey = vec2(cell.y > 0.0 ? local.y : 9.0, cell.y < n.y - 1.0 ? 1.0 - local.y : 9.0) * tile.y * ps;
		float e = min(min(ex.x, ex.y), min(ey.x, ey.y));
		float gh = gap * ps * 0.5;
		float gm = 1.0 - smoothstep(gh - 0.5, gh + 0.5, e);
		gm *= min(1.0, gap * ps);
		col = mix(col, vec4(gap_colour.rgb * gap_colour.a, gap_colour.a) * a0, gm);
	}
	COLOR = col;
}
