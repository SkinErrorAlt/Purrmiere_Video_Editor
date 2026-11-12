shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 position = vec2(0.5, 0.95);
uniform float height : hint_range(0.1, 1.5) = 0.85;
uniform float width : hint_range(0.04, 1.0) = 0.2;
uniform float rise_speed : hint_range(0.0, 3.0) = 0.6;
uniform float billow : hint_range(0.0, 2.0) = 0.7;
uniform float density : hint_range(0.0, 1.0) = 0.6;
uniform float spread : hint_range(0.0, 2.0) = 0.7;
uniform float dissipation : hint_range(0.0, 1.0) = 0.5;
uniform float drift : hint_range(-1.0, 1.0) = 0.1;
uniform float lit_from : hint_range(-180.0, 180.0) = 50.0;
uniform float shade : hint_range(0.0, 1.0) = 0.6;
uniform vec4 colour : source_color = vec4(0.52, 0.52, 0.55, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.85;
uniform int blend : hint_range(0, 6) = 6;
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
	for (int i = 0; i < 6; i++) {
		s += amp * vnoise(p);
		p = m * p;
		amp *= 0.5;
	}
	return s;
}

float smoke_dens(vec2 uv, float t, float sd) {
	float ar = tex_size.x / tex_size.y;
	float up = (position.y - uv.y) / max(height, 0.05);
	float sw = width * (0.5 + spread * clamp(up, 0.0, 2.0) * 1.35);
	float sx = (uv.x - position.x) * ar / max(sw, 0.02);
	sx -= up * drift * 1.3;
	vec2 b = vec2(sx * 0.9, up * 0.9) + sd;
	vec2 flow = vec2(0.0, -t * rise_speed * 0.9);
	vec2 w1 = vec2(fbm(b + flow), fbm(b + flow + vec2(5.2, 1.3)));
	vec2 w2 = vec2(fbm(b * 2.0 + w1 * 1.4 + flow), fbm(b * 2.0 + w1 * 1.4 + vec2(3.1, 2.7) + flow));
	float n = fbm(b * (1.6 + billow) + w2 * 1.3 + flow);
	float horiz = 1.0 - smoothstep(0.62, 1.12, abs(sx));
	float foot = smoothstep(-0.1, 0.08, up);
	float top = 1.0 - smoothstep(0.5, 1.0 + (1.0 - dissipation) * 0.7, up);
	float env = horiz * foot * top;
	return clamp(env * (n * 1.65 - 0.36) * (0.5 + density) * 2.2, 0.0, 1.0);
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
	float t = clip_time;
	float sd = float(seed) * 1.7 + 5.0;

	float dens = smoke_dens(UV, t, sd);
	float ang = radians(lit_from);
	vec2 ld = vec2(cos(ang), -sin(ang)) * 7.0 / max(tex_size, vec2(1.0));
	float dl = smoke_dens(UV + ld, t, sd);
	float db = smoke_dens(UV - ld, t, sd);
	float sh = clamp((db - dl) * 2.2, -1.0, 1.0);
	float ao = 1.0 - clamp(dens * 0.35, 0.0, 0.35);
	vec3 col = colour.rgb * (1.0 + shade * 0.45 * sh) * ao;

	float cov = smoothstep(0.1, 0.5, dens) * opacity * colour.a;
	COLOR = mix_in(rgb, a, col, cov, blend, strength);
}
