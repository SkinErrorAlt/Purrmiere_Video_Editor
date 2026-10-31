shader_type canvas_item;
render_mode blend_disabled;

uniform float balance : hint_range(0.0, 10.0) = 5.0;
uniform float black_intensity : hint_range(0.0, 10.0) = 6.0;
uniform float white_intensity : hint_range(0.0, 10.0) = 2.0;
uniform float stroke_length : hint_range(2.0, 40.0) = 12.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 unp(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

float lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec4 stroke(sampler2D tex, vec2 uv, vec2 dir, vec2 dims, float len, float ps) {
	vec2 st = dir * len * ps / dims / 8.0;
	vec4 s = vec4(0.0);
	for (int i = -4; i <= 4; i++) {
		s += texture(tex, clamp(uv + st * float(i), vec2(0.0), vec2(1.0)));
	}
	return s / 9.0;
}

float lic(vec2 P, vec2 dir, float len, vec2 so) {
	float s = 0.0;
	for (int i = -5; i <= 5; i++) {
		s += h12(floor((P + dir * float(i) * len / 10.0) / 1.6) + so);
	}
	return clamp((s / 11.0 - 0.5) * 3.2 + 0.5, 0.0, 1.0);
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float len = max(stroke_length, 1.0);
	float fs = float(seed);
	vec2 so = vec2(mod(fs * 12.9898, 997.0), mod(fs * 78.233, 991.0));
	vec2 P = UV * dims / ps;
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec2 up_dir = vec2(0.7071, -0.7071);
	vec2 down_dir = vec2(0.7071, 0.7071);
	float threshold = clamp(balance / 10.0, 0.0, 1.0) * 0.7 + 0.15;
	vec3 lc = unp(stroke(TEXTURE, UV, up_dir, dims, len, ps));
	vec3 dc = unp(stroke(TEXTURE, UV, down_dir, dims, len * 0.4, ps));
	float tone = lum(mix(dc, lc, 0.5));
	float jit = (vn(P / (len * 1.5) + so) - 0.5) * 0.08;
	float w = smoothstep(threshold - 0.1, threshold + 0.1, tone + jit);
	float bk = black_intensity / 10.0;
	float wk = white_intensity / 10.0;
	float sl = lic(P, up_dir, len, so);
	float sd = lic(P, down_dir, len * 0.4, so + 37.0);
	vec3 light = mix(lc, vec3(1.0), clamp(wk * (0.3 + 0.7 * sl) * 0.8, 0.0, 1.0));
	light *= 1.0 + (sl - 0.5) * 0.18;
	float sink = bk * (0.55 + 0.45 * sd) * (1.0 - lum(dc) * 0.5);
	vec3 dark = dc * (1.0 - clamp(sink, 0.0, 0.97));
	dark *= 1.0 + (sd - 0.5) * 0.35;
	vec3 col = mix(dark, light, w);
	col = (col - 0.5) * (1.0 + (bk + wk) * 0.15) + 0.5;
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}