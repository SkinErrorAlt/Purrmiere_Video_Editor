shader_type canvas_item;
render_mode blend_disabled;

uniform float scale : hint_range(0.1, 10.0) = 1.0;
uniform float speed : hint_range(0.0, 10.0) = 1.0;
uniform int complexity : hint_range(1, 6) = 3;
uniform int palette : hint_range(0, 3) = 0;
uniform vec4 colour_a : source_color = vec4(0.12, 0.02, 0.3, 1.0);
uniform vec4 colour_b : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform int blend : hint_range(0, 6) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time;

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

vec3 ramp4(vec3 c0, vec3 c1, vec3 c2, vec3 c3, float x) {
	float s = clamp(x, 0.0, 1.0) * 3.0;
	if (s < 1.0) { return mix(c0, c1, s); }
	if (s < 2.0) { return mix(c1, c2, s - 1.0); }
	return mix(c2, c3, s - 2.0);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	vec2 pos = (UV - 0.5) * vec2(sz.x / sz.y, 1.0) * (7.0 / max(scale, 0.01));
	float t = clip_time * speed;
	float v = 0.0;
	float n = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i >= complexity) { break; }
		float fi = float(i);
		float ang = fi * 2.39996 + 0.4;
		vec2 dir = vec2(cos(ang), sin(ang));
		float freq = 1.0 + fi * 0.37;
		v += sin(dot(pos, dir) * freq + t * (0.6 + 0.23 * fi));
		vec2 mover = vec2(sin(t * (0.31 + 0.07 * fi) + fi), cos(t * (0.27 + 0.05 * fi) + fi * 1.7)) * 3.0;
		v += sin(length(pos - mover) * freq * 1.3 - t * (0.9 + 0.1 * fi));
		n += 2.0;
	}
	v /= max(n, 1.0);
	float x = 0.5 + 0.5 * sin(v * 6.2831853 + t * 0.2);
	vec3 gen;
	float ga = 1.0;
	if (palette == 1) {
		gen = ramp4(vec3(0.12, 0.0, 0.0), vec3(0.65, 0.06, 0.0), vec3(1.0, 0.45, 0.0), vec3(1.0, 0.92, 0.45), x);
	} else if (palette == 2) {
		gen = ramp4(vec3(0.0, 0.04, 0.18), vec3(0.0, 0.28, 0.55), vec3(0.08, 0.62, 0.72), vec3(0.75, 0.96, 1.0), x);
	} else if (palette == 3) {
		vec4 pm = mix(vec4(colour_a.rgb * colour_a.a, colour_a.a), vec4(colour_b.rgb * colour_b.a, colour_b.a), x);
		ga = pm.a;
		gen = pm.a > 0.0001 ? pm.rgb / pm.a : vec3(0.0);
	} else {
		gen = 0.5 + 0.5 * cos(6.2831853 * (vec3(x) + vec3(0.0, 0.33, 0.67)));
	}
	COLOR = mix_in(rgb, a, gen, ga, blend, strength);
}
