shader_type canvas_item;
render_mode blend_disabled;

uniform int pattern : hint_range(0, 5) = 1;
uniform int levels : hint_range(2, 32) = 4;
uniform bool monochrome = false;
uniform float pixel_size : hint_range(1.0, 32.0) = 2.0;
uniform float contrast : hint_range(0.0, 3.0) = 1.0;
uniform vec4 dark_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 light_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float bayer(ivec2 p, int bits) {
	int v = 0;
	for (int i = 0; i < 3; i++) {
		if (i >= bits) {
			break;
		}
		int xb = (p.x >> i) & 1;
		int yb = (p.y >> i) & 1;
		int sh = 2 * (bits - 1 - i);
		v = v | ((((xb ^ yb) << 1) | yb) << sh);
	}
	float n = float(1 << (2 * bits));
	return (float(v) + 0.5) / n;
}

float gradient_noise(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

const int ED_ROWS = 5;
const int ED_LEFT = 10;
const int ED_COLS = 17;

vec3 cell_colour(sampler2D tex, vec2 cell, vec2 size, float ps) {
	vec2 cuv = clamp((cell + 0.5) * ps / size, vec2(0.0), vec2(1.0));
	vec4 c = texture(tex, cuv);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	rgb = clamp((rgb - 0.5) * contrast + 0.5, 0.0, 1.0);
	if (monochrome) {
		rgb = vec3(dot(rgb, vec3(0.2126, 0.7152, 0.0722)));
	}
	return rgb;
}

vec3 diffused(sampler2D tex, vec2 cell, vec2 size, float ps, float n, bool atkinson) {
	vec3 err[85];
	for (int i = 0; i < 85; i++) {
		int rr = i / ED_COLS;
		int cc = i - rr * ED_COLS;
		vec2 at = cell + vec2(float(cc - ED_LEFT), float(rr - (ED_ROWS - 1)));
		vec3 h = fract(sin(vec3(dot(at, vec2(12.9898, 78.233)), dot(at, vec2(39.3468, 11.135)), dot(at, vec2(73.156, 52.235)))) * 43758.5453);
		h = vec3(h.x);
		bool edge = rr == 0 || cc == 0;
		err[i] = edge ? (h - 0.5) / n : (h - 0.5) / n * 0.15;
	}
	vec2 cells = floor(size / ps);
	vec3 out_q = vec3(0.0);
	for (int r = 0; r < ED_ROWS; r++) {
		int dy = r - (ED_ROWS - 1);
		float cy = cell.y + float(dy);
		if (cy < 0.0) {
			continue;
		}
		int right = ED_LEFT + (ED_ROWS - 1 - r);
		for (int col = 0; col <= right; col++) {
			float cx = cell.x + float(col - ED_LEFT);
			if (cx < 0.0 || cx >= cells.x) {
				continue;
			}
			int idx = r * ED_COLS + col;
			vec3 v = cell_colour(tex, vec2(cx, cy), size, ps) + err[idx];
			vec3 q = clamp(floor(v * n + 0.5), 0.0, n) / n;
			vec3 e = v - q;
			if (r == ED_ROWS - 1 && col == ED_LEFT) {
				out_q = q;
			}
			if (atkinson) {
				vec3 part = e * 0.125;
				if (col + 1 < ED_COLS) { err[idx + 1] += part; }
				if (col + 2 < ED_COLS) { err[idx + 2] += part; }
				if (r + 1 < ED_ROWS) {
					if (col > 0) { err[idx + ED_COLS - 1] += part; }
					err[idx + ED_COLS] += part;
					if (col + 1 < ED_COLS) { err[idx + ED_COLS + 1] += part; }
				}
				if (r + 2 < ED_ROWS) { err[idx + ED_COLS * 2] += part; }
			} else {
				if (col + 1 < ED_COLS) { err[idx + 1] += e * (7.0 / 16.0); }
				if (r + 1 < ED_ROWS) {
					if (col > 0) { err[idx + ED_COLS - 1] += e * (3.0 / 16.0); }
					err[idx + ED_COLS] += e * (5.0 / 16.0);
					if (col + 1 < ED_COLS) { err[idx + ED_COLS + 1] += e * (1.0 / 16.0); }
				}
			}
		}
	}
	return out_q;
}

float quantise(float v, float n, float t) {
	return clamp(floor(v * n + t), 0.0, n) / n;
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float ps = max(pixel_size * px_scale, 1.0);
	vec2 cell = floor(UV * size / ps);
	vec2 cuv = clamp((cell + 0.5) * ps / size, vec2(0.0), vec2(1.0));
	vec4 c = texture(TEXTURE, cuv);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	rgb = clamp((rgb - 0.5) * contrast + 0.5, 0.0, 1.0);
	if (pattern >= 4) {
		float nd = float(max(levels, 2) - 1);
		vec3 q = diffused(TEXTURE, cell, size, ps, nd, pattern == 5);
		if (monochrome) {
			rgb = mix(dark_colour.rgb, light_colour.rgb, q.r);
		} else {
			rgb = q;
		}
		COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
	} else {
		float t;
		ivec2 ip = ivec2(mod(cell, 8.0));
		if (pattern == 0) {
			t = bayer(ip, 1);
		} else if (pattern == 1) {
			t = bayer(ip, 2);
		} else if (pattern == 2) {
			t = bayer(ip, 3);
		} else {
			t = gradient_noise(cell);
		}
		float n = float(max(levels, 2) - 1);
		if (monochrome) {
			float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
			float q = quantise(luma, n, t);
			rgb = mix(dark_colour.rgb, light_colour.rgb, q);
		} else {
			rgb = vec3(quantise(rgb.r, n, t), quantise(rgb.g, n, t), quantise(rgb.b, n, t));
		}
		COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
	}
}
