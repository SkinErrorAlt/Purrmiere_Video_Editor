shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float texture_coverage : hint_range(0.0, 40.0) = 16.0;
uniform int surface : hint_range(0, 3) = 2;
uniform float scaling : hint_range(50.0, 200.0) = 100.0;
uniform float relief : hint_range(0.0, 50.0) = 4.0;
uniform int light : hint_range(0, 7) = 4;
uniform bool invert = false;
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

float weave(vec2 p, float period, float gap, float rough) {
	vec2 q = p / period;
	vec2 cell = floor(q);
	vec2 f = fract(q);
	bool over = mod(cell.x + cell.y, 2.0) < 1.0;
	float across = over ? f.y : f.x;
	float along = over ? f.x : f.y;
	float thread = sqrt(max(sin(across * 3.14159), 0.0));
	float bulge = 0.75 + 0.25 * sin(along * 3.14159);
	float h = thread * bulge;
	h *= smoothstep(0.0, gap, min(across, 1.0 - across));
	h += (vn(p * vec2(over ? 0.4 : 1.6, over ? 1.6 : 0.4)) - 0.5) * rough;
	return h;
}

float bricks(vec2 p) {
	vec2 sz = vec2(26.0, 12.0);
	float row = floor(p.y / sz.y);
	vec2 q = vec2(p.x + mod(row, 2.0) * sz.x * 0.5, p.y);
	vec2 id = floor(q / sz);
	vec2 f = q - id * sz;
	float m = min(min(f.x, sz.x - f.x), min(f.y, sz.y - f.y));
	float h = smoothstep(0.6, 2.2, m);
	h *= 0.85 + 0.15 * h12(id + 3.0);
	h += (vn(p * 0.7) - 0.5) * 0.18 + (h12(floor(p)) - 0.5) * 0.06;
	return h;
}

float sandstone(vec2 p) {
	return vn(p / 6.0) * 0.5 + vn(p / 2.5 + 9.0) * 0.3 + vn(p / 1.0 + 21.0) * 0.2;
}

float surface_height(vec2 p) {
	if (surface == 0) {
		return bricks(p);
	}
	if (surface == 1) {
		return weave(p, 7.0, 0.22, 0.35);
	}
	if (surface == 3) {
		return sandstone(p);
	}
	return weave(p, 3.2, 0.12, 0.18);
}

vec2 light_dir(int i) {
	if (i == 0) {
		return vec2(0.0, 1.0);
	}
	if (i == 1) {
		return vec2(-0.7071, 0.7071);
	}
	if (i == 2) {
		return vec2(-1.0, 0.0);
	}
	if (i == 3) {
		return vec2(-0.7071, -0.7071);
	}
	if (i == 5) {
		return vec2(0.7071, -0.7071);
	}
	if (i == 6) {
		return vec2(1.0, 0.0);
	}
	if (i == 7) {
		return vec2(0.7071, 0.7071);
	}
	return vec2(0.0, -1.0);
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float fs = float(seed);
	vec2 so = vec2(mod(fs * 12.9898, 997.0), mod(fs * 78.233, 991.0));
	vec2 P = UV * dims / ps;
	vec4 o = texture(effect_tex, UV);
	float a = o.a;
	vec3 orig = a > 0.0001 ? clamp(o.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec4 bs = texture(TEXTURE, UV);
	vec3 under = bs.a > 0.0001 ? clamp(bs.rgb / bs.a, 0.0, 1.0) : orig;
	float cov = clamp(texture_coverage / 40.0, 0.0, 1.0);
	vec3 col = mix(orig, under, 0.6 + cov * 0.3);
	float lo = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(vec3(lo), col, 0.9);
	vec2 tp = (P + so) / max(scaling / 100.0, 0.05);
	float h0 = surface_height(tp);
	float hx = surface_height(tp + vec2(1.0, 0.0));
	float hy = surface_height(tp + vec2(0.0, 1.0));
	vec2 g = vec2(hx - h0, hy - h0);
	float rk = relief / 50.0 * (invert ? -1.0 : 1.0);
	float shade = -dot(g, light_dir(light)) * (0.5 + rk * 6.0) * (0.25 + cov * 0.9);
	col *= 1.0 + clamp(shade, -0.8, 0.8);
	col *= 1.0 + (h0 - 0.6) * cov * 0.35;
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}
