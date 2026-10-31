shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform int palette = 2;
uniform vec4 colour_1 : source_color = vec4(0.98, 0.42, 0.35, 1.0);
uniform vec4 colour_2 : source_color = vec4(0.98, 0.78, 0.35, 1.0);
uniform vec4 colour_3 : source_color = vec4(0.35, 0.5, 0.95, 1.0);
uniform vec4 colour_4 : source_color = vec4(0.12, 0.08, 0.3, 1.0);
uniform float speed : hint_range(0.0, 2.0) = 0.3;
uniform float scale : hint_range(0.2, 3.0) = 1.0;
uniform float swirl : hint_range(0.0, 1.0) = 0.4;
uniform float grain : hint_range(0.0, 1.0) = 0.3;
uniform int blend : hint_range(0, 7) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

vec3 blend_colour(vec3 base, vec3 over_c, int how) {
	if (how == 1) { return base * over_c; }
	if (how == 2) { return 1.0 - (1.0 - base) * (1.0 - over_c); }
	if (how == 3) { return mix(2.0 * base * over_c, 1.0 - 2.0 * (1.0 - base) * (1.0 - over_c), step(0.5, base)); }
	if (how == 4) { return base + over_c; }
	if (how == 5) { return (1.0 - 2.0 * over_c) * base * base + 2.0 * over_c * base; }
	return over_c;
}

vec4 mix_in(vec3 pic, float pic_a, vec3 gen, int how, float amt) {
	vec3 pc = clamp(pic, 0.0, 1.0);
	vec3 g = clamp(gen, 0.0, 1.0);
	float s = clamp(amt, 0.0, 1.0);
	if (how == 0) {
		return mix(vec4(pc * pic_a, pic_a), vec4(g, 1.0), s);
	}
	if (how == 6) {
		return vec4(g * s + pc * pic_a * (1.0 - s), s + pic_a * (1.0 - s));
	}
	if (how == 7) {
		float w = s * (1.0 - pic_a);
		return vec4(pc * pic_a + g * w, pic_a + w);
	}
	vec3 o = mix(pc, blend_colour(pc, g, how), s);
	return vec4(clamp(o, 0.0, 1.0) * pic_a, pic_a);
}

vec3 pal(int p, int i) {
	if (p == 0) {
		if (i == 0) { return vec3(1.0, 0.42, 0.3); }
		if (i == 1) { return vec3(0.98, 0.72, 0.35); }
		if (i == 2) { return vec3(0.62, 0.25, 0.55); }
		return vec3(0.22, 0.13, 0.4);
	}
	if (p == 1) {
		if (i == 0) { return vec3(0.04, 0.32, 0.58); }
		if (i == 1) { return vec3(0.1, 0.68, 0.78); }
		if (i == 2) { return vec3(0.02, 0.14, 0.34); }
		return vec3(0.4, 0.88, 0.82);
	}
	if (p == 2) {
		if (i == 0) { return vec3(0.1, 0.88, 0.6); }
		if (i == 1) { return vec3(0.22, 0.38, 0.95); }
		if (i == 2) { return vec3(0.58, 0.2, 0.85); }
		return vec3(0.03, 0.07, 0.2);
	}
	if (p == 3) {
		if (i == 0) { return vec3(1.0, 0.1, 0.6); }
		if (i == 1) { return vec3(0.1, 0.9, 1.0); }
		if (i == 2) { return vec3(0.5, 0.1, 1.0); }
		return vec3(0.06, 0.02, 0.15);
	}
	if (p == 4) {
		if (i == 0) { return vec3(1.0, 0.62, 0.8); }
		if (i == 1) { return vec3(0.62, 0.8, 1.0); }
		if (i == 2) { return vec3(1.0, 0.94, 0.62); }
		return vec3(0.76, 0.62, 1.0);
	}
	if (p == 5) {
		if (i == 0) { return vec3(0.1, 0.36, 0.2); }
		if (i == 1) { return vec3(0.5, 0.7, 0.3); }
		if (i == 2) { return vec3(0.05, 0.2, 0.15); }
		return vec3(0.85, 0.8, 0.45);
	}
	if (i == 0) { return colour_1.rgb; }
	if (i == 1) { return colour_2.rgb; }
	if (i == 2) { return colour_3.rgb; }
	return colour_4.rgb;
}

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec3 to_lin(vec3 c) {
	return pow(max(c, vec3(0.0)), vec3(2.2));
}

vec3 to_gamma(vec3 c) {
	return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));
}

void fragment() {
	vec4 pic = texture(TEXTURE, UV);
	float asp = max(tex_size.x, 1.0) / max(tex_size.y, 1.0);
	vec2 p = (UV - 0.5) * vec2(asp, 1.0);
	float t = clip_time * clamp(speed, 0.0, 2.0);
	float sw = clamp(swirl, 0.0, 1.0);
	vec2 warp = vec2(vnoise(p * 2.2 + vec2(t * 0.35, 1.7)), vnoise(p * 2.2 + vec2(4.1, t * 0.3))) - 0.5;
	p += warp * sw * 0.5;
	float ang = sw * 1.2 * sin(t * 0.4) * exp(-dot(p, p) * 2.0);
	p = vec2(cos(ang) * p.x - sin(ang) * p.y, sin(ang) * p.x + cos(ang) * p.y);
	float sc = clamp(scale, 0.2, 3.0);
	vec3 acc = vec3(0.0);
	float wsum = 0.0;
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		vec2 c = vec2(sin(t * (0.53 + fi * 0.17) + fi * 1.9) * asp * 0.42, cos(t * (0.41 + fi * 0.13) + fi * 2.7) * 0.42);
		float d2 = dot(p - c, p - c);
		float w = exp(-d2 / (0.18 * sc * sc)) + 0.002;
		acc += to_lin(pal(palette, i)) * w;
		wsum += w;
	}
	vec3 gen = to_gamma(acc / max(wsum, 0.000001));
	float n = hash(floor(UV / max(fwidth(UV), vec2(0.000001))) + vec2(floor(fract(clip_time * 7.13) * 97.0) * 13.0)) - 0.5;
	gen += n * clamp(grain, 0.0, 1.0) * 0.05;
	vec3 rgb = pic.a > 0.0001 ? pic.rgb / pic.a : vec3(0.0);
	COLOR = mix_in(rgb, pic.a, gen, blend, strength);
}
