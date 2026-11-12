shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform int mode : hint_range(0, 2) = 0;
uniform float threshold : hint_range(0.0, 1.0) = 0.75;
uniform float depth : hint_range(0.0, 1.0) = 0.8;
uniform float speed : hint_range(0.1, 4.0) = 1.0;
uniform float independence : hint_range(0.0, 1.0) = 0.8;
uniform int seed : hint_range(0, 9999) = 11;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash11(i), hash11(i + 1.0), u);
}

float bulb(float t, float salt) {
	float g = 1.0 - 0.07 * noise1(t * 17.0 + salt * 31.0) - 0.04 * noise1(t * 41.0 + salt * 7.0);
	float slot = floor(t * 1.6 + salt * 5.0);
	float ev = hash11(slot * 1.37 + salt * 91.0);
	float local = fract(t * 1.6 + salt * 5.0);
	float start = hash11(slot * 3.1 + salt * 17.0) * 0.5;
	float len = 0.12 + 0.3 * hash11(slot * 7.7 + salt * 3.0);
	float inside = step(start, local) * step(local, start + len);
	float chatter = step(0.45, hash11(floor(t * 26.0) * 1.91 + salt * 13.0));
	float drop = ev > 0.72 ? inside * chatter : 0.0;
	g = mix(g, 0.06, drop);
	float brown = smoothstep(0.7, 0.95, noise1(t * 0.55 + salt * 11.0));
	return g * (1.0 - 0.55 * brown);
}

float tube(float t, float salt) {
	float g = 1.0 - 0.035 * (0.5 + 0.5 * sin(t * 43.98 + salt * 6.0)) - 0.02 * noise1(t * 9.0 + salt * 5.0);
	float slot = floor(t * 0.9 + salt * 3.0);
	float ev = hash11(slot * 2.17 + salt * 57.0);
	float local = fract(t * 0.9 + salt * 3.0);
	float start = hash11(slot * 5.3 + salt * 23.0) * 0.45;
	float len = 0.25 + 0.3 * hash11(slot * 9.1 + salt * 2.0);
	float inside = step(start, local) * step(local, start + len);
	float strobe = hash11(floor(t * 14.0) * 2.71 + salt * 19.0);
	float strike = ev > 0.62 ? inside : 0.0;
	float level = strobe > 0.5 ? 1.08 : mix(0.12, 0.45, strobe * 2.0);
	return mix(g, level, strike);
}

float flame(float t, float salt) {
	float n = noise1(t * 3.1 + salt * 13.0) * 0.5 + noise1(t * 7.3 + salt * 29.0) * 0.3 + noise1(t * 15.7 + salt * 3.0) * 0.2;
	float g = 0.72 + 0.48 * n;
	float gutter = smoothstep(0.78, 0.97, noise1(t * 0.9 + salt * 41.0));
	return g * (1.0 - 0.4 * gutter);
}

float lamp_gain(float t, float salt) {
	float g = 1.0;
	if (mode == 1) {
		g = tube(t, salt);
	} else if (mode == 2) {
		g = flame(t, salt);
	} else {
		g = bulb(t, salt);
	}
	return 1.0 + (g - 1.0) * clamp(depth, 0.0, 1.0);
}

float peak(vec4 c) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	return max(rgb.r, max(rgb.g, rgb.b)) * c.a;
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float aspect = size.y / size.x;
	float around = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398 + 0.3;
		vec2 d = vec2(cos(a) * aspect, sin(a));
		around += peak(texture(TEXTURE, UV + d * 0.06));
	}
	around /= 8.0;
	vec2 px = 0.5 / size;
	float mx = (peak(texture(TEXTURE, UV + vec2(-px.x, -px.y))) + peak(texture(TEXTURE, UV + vec2(px.x, -px.y))) + peak(texture(TEXTURE, UV + vec2(-px.x, px.y))) + peak(texture(TEXTURE, UV + vec2(px.x, px.y)))) * 0.25;
	float src = smoothstep(threshold, mix(threshold, 1.0, 0.5) + 0.02, mx) * mix(1.0, smoothstep(0.02, 0.25, mx - around), 0.7);
	float sd = float(seed) * 0.6180339;
	float t = max(clip_time, 0.0) * clamp(speed, 0.1, 4.0);
	vec2 grid = UV * vec2(5.0, 3.0);
	vec2 cell = floor(grid);
	vec2 fr = fract(grid);
	vec2 bl = smoothstep(vec2(0.85), vec2(1.0), fr);
	float g00 = lamp_gain(t, hash12(cell + sd) * 10.0 + 1.0);
	float g10 = lamp_gain(t, hash12(cell + vec2(1.0, 0.0) + sd) * 10.0 + 1.0);
	float g01 = lamp_gain(t, hash12(cell + vec2(0.0, 1.0) + sd) * 10.0 + 1.0);
	float g11 = lamp_gain(t, hash12(cell + vec2(1.0, 1.0) + sd) * 10.0 + 1.0);
	float own = mix(mix(g00, g10, bl.x), mix(g01, g11, bl.x), bl.y);
	float shared = lamp_gain(t, sd * 3.0 + 0.5);
	float g = mix(shared, own, clamp(independence, 0.0, 1.0));
	COLOR = vec4(sqrt(clamp(src, 0.0, 1.0)), sqrt(clamp(src * max(1.0 - g, 0.0), 0.0, 1.0)), sqrt(clamp(src * max(g - 1.0, 0.0) * 4.0, 0.0, 1.0)), 1.0);
}
