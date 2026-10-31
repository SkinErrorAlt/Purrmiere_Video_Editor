shader_type canvas_item;
render_mode blend_disabled;

uniform float direction_balance : hint_range(0.0, 100.0) = 50.0;
uniform float stroke_length : hint_range(3.0, 50.0) = 15.0;
uniform float sharpness : hint_range(0.0, 10.0) = 3.0;
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
	vec2 st = dir * len * ps / dims / 10.0;
	vec4 s = vec4(0.0);
	for (int i = -5; i <= 5; i++) {
		s += texture(tex, clamp(uv + st * float(i), vec2(0.0), vec2(1.0)));
	}
	return s / 11.0;
}

float lic(vec2 P, vec2 dir, float len, vec2 so) {
	float s = 0.0;
	for (int i = -6; i <= 6; i++) {
		s += h12(floor((P + dir * float(i) * len / 12.0) / 1.8) + so);
	}
	return clamp((s / 13.0 - 0.5) * 3.2 + 0.5, 0.0, 1.0);
}

vec3 painted(sampler2D tex, vec2 uv, vec2 P, vec2 dir, vec2 dims, float len, float ps, float k, vec3 orig, vec2 so) {
	vec3 col = unp(stroke(tex, uv, dir, dims, len, ps));
	vec3 wide = unp(stroke(tex, uv, dir, dims, len * 2.0, ps));
	col = mix(col, orig, 0.1 + k * 0.15);
	col += (col - wide) * k * 0.8;
	float streak = lic(P, dir, len, so);
	return col * (1.0 + (streak - 0.5) * (0.3 + k * 0.35));
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
	vec3 orig = unp(c);
	vec2 r = vec2(len * 0.3 * ps) / dims;
	float tone = lum(orig) * 0.4 + lum(unp(texture(TEXTURE, clamp(UV + vec2(r.x, 0.0), vec2(0.0), vec2(1.0))))) * 0.15 + lum(unp(texture(TEXTURE, clamp(UV - vec2(r.x, 0.0), vec2(0.0), vec2(1.0))))) * 0.15 + lum(unp(texture(TEXTURE, clamp(UV + vec2(0.0, r.y), vec2(0.0), vec2(1.0))))) * 0.15 + lum(unp(texture(TEXTURE, clamp(UV - vec2(0.0, r.y), vec2(0.0), vec2(1.0))))) * 0.15;
	float threshold = 1.0 - direction_balance / 100.0;
	float jit = (vn(P / (len * 2.0) + so) - 0.5) * 0.1;
	float w = smoothstep(threshold - 0.06, threshold + 0.06, tone + jit);
	if (direction_balance >= 100.0) {
		w = 1.0;
	}
	if (direction_balance <= 0.0) {
		w = 0.0;
	}
	float k = sharpness / 10.0;
	vec3 col = vec3(0.0);
	if (w > 0.001) {
		col += painted(TEXTURE, UV, P, vec2(0.7071, -0.7071), dims, len, ps, k, orig, so) * w;
	}
	if (w < 0.999) {
		col += painted(TEXTURE, UV, P, vec2(0.7071, 0.7071), dims, len, ps, k, orig, so + 91.0) * (1.0 - w);
	}
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}