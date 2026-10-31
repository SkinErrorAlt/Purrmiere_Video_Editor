shader_type canvas_item;
render_mode blend_disabled;

uniform int count : hint_range(1, 64) = 18;
uniform float size : hint_range(4.0, 600.0) = 70.0;
uniform float size_spread : hint_range(0.0, 1.0) = 0.5;
uniform float softness : hint_range(0.0, 1.0) = 0.35;
uniform float speed : hint_range(0.0, 4.0) = 0.4;
uniform float pulse : hint_range(0.0, 1.0) = 0.3;
uniform vec4 colour_a : source_color = vec4(1.0, 0.72, 0.35, 1.0);
uniform vec4 colour_b : source_color = vec4(0.45, 0.7, 1.0, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform int blend : hint_range(0, 6) = 2;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 blend_colour(vec3 base, vec3 over, int how) {
	if (how == 1) { return base * over; }
	if (how == 2) { return 1.0 - (1.0 - base) * (1.0 - over); }
	if (how == 3) { return mix(2.0 * base * over, 1.0 - 2.0 * (1.0 - base) * (1.0 - over), step(0.5, base)); }
	if (how == 4) { return base + over; }
	if (how == 5) { return (1.0 - 2.0 * over) * base * base + 2.0 * over * base; }
	return over;
}

vec4 mix_in(vec3 pic, float pic_a, vec3 gen, float cov, int how, float amt) {
	vec3 pc = clamp(pic, 0.0, 1.0);
	vec3 g = clamp(gen, 0.0, 1.0);
	float s = clamp(amt, 0.0, 1.0);
	float k = clamp(cov, 0.0, 1.0);
	if (how == 0) {
		return mix(vec4(pc * pic_a, pic_a), vec4(g * k, k), s);
	}
	if (how == 6) {
		float w = k * s;
		return vec4(g * w + pc * pic_a * (1.0 - w), w + pic_a * (1.0 - w));
	}
	vec3 o = mix(pc, blend_colour(pc, g, how), k * s);
	return vec4(clamp(o, 0.0, 1.0) * pic_a, pic_a);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 skey = floor(hash22(vec2(float(seed) * 0.7123 + 3.1, 11.7)) * 997.0);
	float soft_k = clamp(softness, 0.0, 1.0);
	float clear = 1.0;
	vec3 acc = vec3(0.0);
	float wsum = 0.0;
	for (int i = 0; i < 64; i++) {
		if (i >= count) { break; }
		float fi = float(i);
		vec2 h1 = hash22(vec2(fi * 1.37 + 11.0, 3.3) + skey);
		vec2 h2 = hash22(vec2(fi * 2.11 + 5.0, 7.9) + skey);
		vec2 h3 = hash22(vec2(fi * 0.73 + 17.0, 1.1) + skey);
		float r = max(size * ps * (1.0 - clamp(size_spread, 0.0, 1.0) * 0.8 * h2.x), 1.0);
		vec2 m = vec2(r) / sz;
		float ang = 6.2831853 * h2.y;
		vec2 vel = vec2(cos(ang), sin(ang)) * speed * 0.025 * (0.5 + h3.x);
		vec2 wob = 0.01 * speed * vec2(sin(clip_time * (0.4 + h3.y) + fi), cos(clip_time * (0.3 + h3.x) + fi * 1.3));
		vec2 u = fract(h1 + vel * clip_time + wob);
		vec2 ctr = -m + u * (1.0 + 2.0 * m);
		float d = length((UV - ctr) * sz);
		float sw = max(soft_k * r, 1.0);
		float disc = 1.0 - smoothstep(r - sw, r, d);
		float rim = smoothstep(r * 0.55, r, d) * (1.0 - soft_k);
		float body = disc * (0.75 + 0.25 * rim);
		float beat = 1.0 - clamp(pulse, 0.0, 1.0) * (0.5 + 0.5 * sin(clip_time * (0.8 + 1.2 * h3.y) + 6.2831853 * h1.x));
		vec4 oc = mix(colour_a, colour_b, h3.y);
		float oa = clamp(body * (0.3 + 0.35 * h3.x) * beat * oc.a, 0.0, 1.0);
		acc += oc.rgb * oa;
		wsum += oa;
		clear *= 1.0 - oa;
	}
	vec3 gen = acc / max(wsum, 0.0001);
	float cov = 1.0 - clear;
	COLOR = mix_in(rgb, a, gen, cov, blend, strength);
}
