shader_type canvas_item;
render_mode blend_disabled;

uniform float coil : hint_range(8.0, 120.0) = 34.0;
uniform float strip : hint_range(1.0, 8.0) = 3.4;
uniform float looseness : hint_range(0.0, 1.0) = 0.5;
uniform int papers : hint_range(2, 10) = 5;
uniform float depth : hint_range(0.0, 1.0) = 0.7;
uniform float light_angle : hint_range(-180.0, 180.0) = -130.0;
uniform vec4 backing : source_color = vec4(0.94, 0.92, 0.88, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

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

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

vec3 paper_of(vec3 c) {
	vec3 h = rgb2hsv(clamp(c, 0.0, 1.0));
	float grey = step(h.y * smoothstep(0.08, 0.3, h.z), 0.1);
	float n = float(max(papers, 2) - 1);
	h.x = floor(h.x * 12.0 + 0.5) / 12.0;
	h.y = mix(clamp(floor(h.y * 3.0 + 0.4) / 3.0 * 1.1, 0.0, 1.0), 0.03, grey);
	h.z = (floor(h.z * n + 0.5) + 0.35) / (n + 0.5);
	return hsv2rgb(h);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float ps = max(px_scale, 0.0001);
	vec2 p = UV * tex_size / ps;
	vec2 to_uv = ps / tex_size;
	vec2 so = vec2(float(seed) * 3.03, float(seed) * 1.61);
	float C = max(coil, 4.0);
	vec2 g = p / C;
	vec2 gi = floor(g);
	float d1 = 9.0;
	float d2 = 9.0;
	vec2 s1 = vec2(0.0);
	vec2 id1 = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = gi + vec2(float(x), float(y));
			vec2 s = o + 0.15 + 0.7 * h22(o + so);
			float d = distance(g, s) - 0.32 * h12(o + so + 11.0);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				s1 = s;
				id1 = o;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float la = radians(light_angle);
	vec2 L2 = vec2(cos(la), sin(la));
	vec2 off = (h22(id1 + so + 7.0) - 0.5) * 0.5 * looseness;
	vec2 ctr = s1 + off * (d1 + d2) * 0.5;
	vec2 rv = (g - ctr) * C;
	float rpx = length(rv);
	float edge_px = (d2 - d1) * C * 0.5;
	float rad_px = rpx + edge_px;
	float rn = rpx / max(rad_px, 0.001);
	float wgt = 1.0 - 0.32 * h12(id1 + so + 11.0);
	float roundm = rpx / (0.47 * C * (1.25 - wgt * 0.5));
	float m = mix(roundm, rn, 0.35 + 0.6 * looseness);
	float inside_coil = 1.0 - smoothstep(0.9, 0.9 + 1.2 / max(rad_px, 1.0), m);
	float a = atan(rv.y, rv.x);
	float sp = max(strip, 0.6) * mix(1.0, 1.6, looseness * rn);
	float turns = rad_px / sp;
	float phase = rn * turns - a / 6.2831853;
	float fp = fract(phase);
	float wall = abs(fp - 0.5) * 2.0;
	float lw = clamp(0.9 / max(sp, 0.5), 0.18, 0.6);
	float lip = smoothstep(1.0 - lw - 0.12, 1.0 - lw + 0.08, wall);
	vec2 radial = rpx > 0.001 ? rv / rpx : vec2(0.0);
	float facing = dot(radial, -L2);
	vec4 sc = texture(TEXTURE, clamp(ctr * C * to_uv, vec2(0.0), vec2(1.0)));
	vec3 pc = paper_of(sc.rgb / max(sc.a, 0.0001));
	pc *= 0.96 + 0.08 * h12(id1 + so + 2.0);
	float gap = 1.0 - smoothstep(0.0, 1.0, wall);
	vec3 top = pc * (1.05 + 0.15 * facing * depth) + vec3(0.12 + 0.07 * facing) * depth;
	float well_t = clamp(1.0 - wall, 0.0, 1.0);
	vec3 inside = pc * mix(1.0, 0.32 + 0.3 * (facing * 0.5 + 0.5) + 0.2 * well_t, depth);
	vec3 col = mix(inside, top, lip);
	float centre = 1.0 - smoothstep(0.6 * sp, 1.4 * sp, rpx);
	col = mix(col, pc * (0.55 + 0.3 * depth), centre * 0.7);
	float outer = smoothstep(0.86, 0.9, m) * inside_coil;
	col = mix(col, top, outer * 0.85);
	float boundary = max(1.0 - smoothstep(0.2, 0.9, edge_px), 1.0 - inside_coil);
	float shade_side = clamp(dot(radial, L2), 0.0, 1.0);
	vec3 bk = backing.rgb * (0.94 + 0.06 * vnoise(p * 0.2 + so));
	vec3 bk_shadow = bk * mix(1.0, 0.35, depth);
	col = mix(col, mix(bk * 0.85, bk_shadow, shade_side), boundary * 0.9);
	col *= 0.97 + 0.05 * vnoise(p * 0.6 + so);
	COLOR = vec4(clamp(col, 0.0, 1.0) * base.a, base.a);
}
