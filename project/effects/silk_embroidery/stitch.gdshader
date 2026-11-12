shader_type canvas_item;
render_mode blend_disabled;

uniform float stitch_length : hint_range(4.0, 80.0) = 20.0;
uniform float thread_width : hint_range(1.0, 12.0) = 3.0;
uniform int follow = 0;
uniform float angle : hint_range(-180.0, 180.0) = 60.0;
uniform int colours : hint_range(0, 32) = 9;
uniform float sheen : hint_range(0.0, 1.0) = 0.65;
uniform float light_angle : hint_range(-180.0, 180.0) = 135.0;
uniform float bare : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cloth : source_color = vec4(0.86, 0.82, 0.73, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform sampler2D effect_tex : filter_linear, repeat_disable;

float h12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 h22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec2 dir_at(sampler2D tex, vec2 uv, vec2 flat_dir) {
	vec4 f = texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
	vec2 j = f.xy * 2.0 - 1.0;
	float a = 0.5 * atan(j.y, j.x + 0.0000001);
	vec2 g = vec2(cos(a), sin(a));
	vec2 d = follow == 1 ? g : vec2(-g.y, g.x);
	if (dot(d, flat_dir) < 0.0) {
		d = -d;
	}
	float conf = smoothstep(0.08, 0.5, f.z);
	if (follow == 2) {
		conf = 0.0;
	}
	return normalize(mix(flat_dir, d, conf) + vec2(0.00001, 0.0));
}

vec3 thread_col(vec3 c) {
	if (colours <= 0) {
		return c;
	}
	float n = float(colours);
	return floor(c * n + 0.5) / n;
}

void fragment() {
	vec2 out_size = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float ps = max(px_scale * out_size.x / max(tex_size.x, 1.0), 0.0001);
	vec4 base = texture(effect_tex, UV);
	vec2 p = UV * out_size / ps;
	vec2 so = vec2(float(seed) * 7.13, float(seed) * 3.71);
	float L = max(stitch_length, 2.0);
	float W = max(thread_width, 0.6);
	float fa = radians(angle);
	vec2 flat_dir = vec2(cos(fa), sin(fa));
	float cell = L * 3.2;
	vec2 g = p / cell;
	vec2 gi = floor(g);
	float d1 = 1e9;
	float d2 = 1e9;
	vec2 best = vec2(0.0);
	vec2 best_id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 id = gi + vec2(float(x), float(y));
			vec2 s = (id + 0.1 + 0.8 * h22(id + so)) * cell;
			float dd = distance(p, s);
			if (dd < d1) {
				d2 = d1;
				d1 = dd;
				best = s;
				best_id = id;
			} else if (dd < d2) {
				d2 = dd;
			}
		}
	}
	vec2 d = dir_at(TEXTURE, UV, flat_dir);
	vec2 n = vec2(-d.y, d.x);
	vec2 lp = p - best;
	float u = dot(lp, d);
	float v = dot(lp, n);
	float rowf = v / W + h12(best_id + so * 1.7);
	float row = floor(rowf);
	float tv = fract(rowf);
	float off = mod(row, 2.0) * 0.5 + 0.35 * h12(vec2(row, 3.0) + best_id + so);
	float lenk = 1.0 + 0.35 * (h12(vec2(row, 9.0) + best_id.yx + so) - 0.5);
	float sf = u / (L * lenk) + off;
	float seg = floor(sf);
	float tu = fract(sf);
	float uc = (seg + 0.5 - off) * L * lenk;
	float vc = (row + 0.5 - h12(best_id + so * 1.7)) * W;
	vec2 centre = best + d * uc + n * vc;
	vec2 cuv = clamp(centre * ps / out_size, vec2(0.0), vec2(1.0));
	vec4 src = texture(effect_tex, cuv);
	vec3 col = src.rgb / max(src.a, 0.0001);
	col = thread_col(col);
	float jit = h12(vec2(seg, row) + best_id * 3.1 + so);
	col *= 0.93 + 0.12 * jit;
	float x = tv * 2.0 - 1.0;
	float nz = sqrt(max(1.0 - x * x, 0.0));
	float la = radians(light_angle);
	vec3 lv = normalize(vec3(cos(la), sin(la), 0.9));
	vec3 nn = normalize(vec3(n * x, nz + 0.001));
	float diff = clamp(dot(nn, lv), 0.0, 1.0);
	vec3 T = vec3(d, 0.0);
	vec3 H = normalize(lv + vec3(0.0, 0.0, 1.0));
	float th = dot(T, H);
	float aniso = pow(sqrt(max(1.0 - th * th, 0.0)), 28.0);
	float twist = 0.5 + 0.5 * sin((u / (W * 0.85) + x * 1.4) * 6.2831853 * 0.5);
	float ply = mix(0.92, 1.0, twist);
	float eg = 1.4 / (L * lenk);
	float endgap = smoothstep(0.0, eg, tu) * smoothstep(0.0, eg, 1.0 - tu);
	float endround = mix(0.82, 1.0, smoothstep(0.0, 4.0 * eg, tu) * smoothstep(0.0, 4.0 * eg, 1.0 - tu));
	float sidegap = smoothstep(0.0, 0.35, nz);
	float seam = mix(0.9, 1.0, smoothstep(0.3, 1.2, d2 - d1));
	vec3 thread = col * (0.5 + 0.55 * diff) * ply;
	thread += sheen * aniso * (0.35 + 0.65 * nz) * mix(vec3(1.0), col * 1.3 + 0.2, 0.35) * 0.85;
	float cover = mix(0.45, 1.0, endgap) * seam * mix(0.7, 1.0, sidegap);
	thread *= endround;
	vec2 cp = p / max(W * 0.55, 0.5);
	float weave_x = 0.5 + 0.5 * sin(cp.x * 3.14159);
	float weave_y = 0.5 + 0.5 * sin(cp.y * 3.14159);
	float wv = mix(weave_x, weave_y, step(0.5, fract(floor(cp.x) * 0.5 + floor(cp.y) * 0.5)));
	vec3 clothc = cloth.rgb * (0.8 + 0.2 * wv) * (0.92 + 0.12 * vnoise(p * 0.08 + so));
	vec3 under = mix(clothc * 0.55, col * 0.35, 0.5);
	vec3 shown = mix(under, thread, cover);
	if (bare > 0.0) {
		float lpic = dot(col, vec3(0.2126, 0.7152, 0.0722));
		float leave = smoothstep(1.0 - bare - 0.04, 1.0 - bare + 0.04, lpic + 0.08 * (vnoise(p * 0.03 + so) - 0.5));
		shown = mix(shown, clothc, leave);
	}
	shown = clamp(shown, 0.0, 1.0);
	COLOR = vec4(shown * base.a, base.a);
}
