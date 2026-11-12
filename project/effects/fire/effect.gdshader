shader_type canvas_item;
render_mode blend_disabled;

uniform int style : hint_range(0, 3) = 0;
uniform vec2 position = vec2(0.5, 0.92);
uniform float height : hint_range(0.1, 1.5) = 0.55;
uniform float width : hint_range(0.04, 1.0) = 0.32;
uniform float intensity : hint_range(0.0, 3.0) = 1.0;
uniform float turbulence : hint_range(0.0, 2.0) = 0.6;
uniform float rise_speed : hint_range(0.0, 3.0) = 1.0;
uniform float flicker : hint_range(0.0, 1.0) = 0.5;
uniform float lean : hint_range(-60.0, 60.0) = 0.0;
uniform int palette : hint_range(0, 3) = 0;
uniform float embers : hint_range(0.0, 1.0) = 0.3;
uniform float smoky_tip : hint_range(0.0, 1.0) = 0.4;
uniform int blend : hint_range(0, 6) = 4;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

vec4 hash42(vec2 p) {
	vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	p4 += dot(p4, p4.wzxy + 33.33);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = h21(i);
	float b = h21(i + vec2(1.0, 0.0));
	float c = h21(i + vec2(0.0, 1.0));
	float d = h21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float amp = 0.5;
	mat2 m = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
	for (int i = 0; i < 5; i++) {
		s += amp * vnoise(p);
		p = m * p;
		amp *= 0.5;
	}
	return s;
}

vec3 fire_ramp(float x) {
	x = clamp(x, 0.0, 1.0);
	vec3 dark = vec3(0.12, 0.01, 0.0);
	vec3 red = vec3(0.75, 0.09, 0.01);
	vec3 orange = vec3(1.0, 0.42, 0.06);
	vec3 yellow = vec3(1.0, 0.86, 0.34);
	vec3 white = vec3(1.0, 0.98, 0.9);
	vec3 c = mix(dark, red, smoothstep(0.0, 0.28, x));
	c = mix(c, orange, smoothstep(0.24, 0.52, x));
	c = mix(c, yellow, smoothstep(0.52, 0.8, x));
	c = mix(c, white, smoothstep(0.82, 1.0, x));
	return c;
}

vec3 palette_shift(vec3 c, int pal) {
	if (pal == 1) {
		return vec3(c.b * 0.5 + c.g * 0.2, c.g * 0.6 + c.r * 0.1, c.r * 0.9 + c.g * 0.3);
	}
	if (pal == 2) {
		return vec3(c.g * 0.25, c.r * 0.85 + c.g * 0.2, c.b * 0.2 + c.g * 0.15);
	}
	if (pal == 3) {
		return vec3(c.r, c.g * 0.82, c.b * 0.55);
	}
	return c;
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
	vec3 g = clamp(gen, 0.0, 4.0);
	float s = clamp(amt, 0.0, 1.0);
	float k = clamp(cov, 0.0, 1.0);
	if (how == 0) {
		return mix(vec4(pc * pic_a, pic_a), vec4(clamp(g, 0.0, 1.0) * k, k), s);
	}
	if (how == 6) {
		float w = k * s;
		return vec4(clamp(g, 0.0, 1.0) * w + pc * pic_a * (1.0 - w), w + pic_a * (1.0 - w));
	}
	vec3 o = mix(pc, blend_colour(pc, g, how), k * s);
	return vec4(clamp(o, 0.0, 1.0) * pic_a, pic_a);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	float ar = sz.x / sz.y;
	float t = clip_time;
	float sd = float(seed) * 1.7 + 11.3;

	vec2 p = UV;
	float H = max(height, 0.05);
	float up = (position.y - p.y) / H;
	float sx = (p.x - position.x) * ar / max(width, 0.02);
	bool fireball = style == 3;

	if (fireball) {
		vec2 rv = vec2((p.x - position.x) * ar, (p.y - position.y)) / max(width, 0.02);
		float rr = length(rv);
		up = 1.0 - rr;
		sx = atan(rv.y, rv.x) * 0.5;
	}

	sx -= up * tan(radians(lean));
	float halfw = style == 2 ? 100.0 : (style == 1 ? 0.55 : 1.0);

	vec2 fuv = vec2(sx * 1.8, up * 2.0) + vec2(0.0, -t * rise_speed * 1.4) + sd;
	float warp = fbm(fuv * 0.9 + vec2(sd, -t * rise_speed * 0.6));
	float n = fbm(vec2(fuv.x + warp * 0.9, fuv.y) * (1.1 + turbulence * 0.9));
	float n2 = fbm(fuv * (2.2 + turbulence) + warp * 0.5 + 7.0);

	float grad = fireball ? clamp(up, 0.0, 1.0) : clamp(1.0 - up, 0.0, 1.0);
	float horiz = (fireball || style == 2) ? 1.0 : (1.0 - smoothstep(halfw * 0.5, halfw * 1.02, abs(sx)));
	float base_n = fbm(vec2(sx * 2.6 + sd, t * 0.6));
	float foot = fireball ? 1.0 : smoothstep(-0.13 - 0.07 * base_n, 0.05, up);
	float pot = horiz * foot * (grad + (n - 0.45) * 0.95) - (fireball ? 0.0 : up * 0.06);
	float d = smoothstep(0.2, 0.52, pot);
	d *= 0.85 + 0.3 * n2;

	float fk = clamp(flicker, 0.0, 1.0);
	float fl = 1.0 - fk * 0.4 * (0.5 + 0.5 * sin(t * (7.0 + 3.0 * warp) + sd * 2.1));
	float hbias = fireball ? (1.0 - up) * 0.3 : up * 0.22;
	float heat = clamp((pot - hbias) * 1.18, 0.0, 1.0);
	heat *= 0.8 + 0.24 * n2 + 0.08 * n;
	vec3 col = palette_shift(fire_ramp(heat), palette) * intensity * fl;

	float tip = 1.0 - clamp(smoky_tip, 0.0, 1.0) * smoothstep(0.5, 1.0, up);
	float cov = clamp(d * tip, 0.0, 1.0);

	if (embers > 0.001 && !fireball) {
		float er = max(2.0 * px_scale, 1.0);
		float cell = er * 26.0;
		vec2 ev = vec2(0.12 * sin(t * 0.7 + sd), -0.6 * max(rise_speed, 0.2)) * sz.y;
		vec2 q = p * sz - mod(ev * t, vec2(cell * 512.0));
		vec2 g = q / cell + vec2(sd, 1.9);
		vec2 cid = floor(g);
		vec2 f = g - cid;
		vec4 hh = hash42(mod(cid, 512.0) + sd);
		float live = step(hh.x, embers * 0.5);
		vec2 ectr = 0.3 + 0.4 * hh.yz;
		float ed = length((f - ectr) * cell);
		float espark = live * (1.0 - smoothstep(er * 0.5, er * 1.6, ed));
		float efade = smoothstep(1.1, 0.2, up) * (0.6 + 0.4 * sin(t * 9.0 + hh.w * 40.0));
		vec3 ecol = palette_shift(vec3(1.0, 0.55, 0.15), palette);
		col += ecol * espark * efade * intensity;
		cov = clamp(cov + espark * efade, 0.0, 1.0);
	}

	COLOR = mix_in(rgb, a, col, cov, blend, strength);
}
