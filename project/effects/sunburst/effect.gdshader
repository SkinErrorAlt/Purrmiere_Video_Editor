shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform int rays : hint_range(3, 64) = 16;
uniform float spin : hint_range(-360.0, 360.0) = 20.0;
uniform vec4 colour_a : source_color = vec4(1.0, 0.8, 0.22, 1.0);
uniform vec4 colour_b : source_color = vec4(1.0, 0.48, 0.1, 1.0);
uniform float softness : hint_range(0.0, 1.0) = 0.1;
uniform float twist : hint_range(-3.0, 3.0) = 0.0;
uniform float glow : hint_range(0.0, 1.0) = 0.5;
uniform int blend : hint_range(0, 7) = 3;
uniform float strength : hint_range(0.0, 1.0) = 0.6;

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
	if (how == 7) {
		float w = k * s * (1.0 - pic_a);
		return vec4(pc * pic_a + g * w, pic_a + w);
	}
	vec3 o = mix(pc, blend_colour(pc, g, how), k * s);
	return vec4(clamp(o, 0.0, 1.0) * pic_a, pic_a);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 sz = max(tex_size, vec2(1.0));
	vec2 p = (UV - centre) * sz / sz.y;
	float r = length(p);
	float n = float(clamp(rays, 3, 64));
	float ang = atan(p.y, p.x) + twist * r * 3.0 - radians(spin) * clip_time;
	float s = fract(ang / 6.2831853 * n);
	float tri = abs(s - 0.5) * 2.0;
	float aa = fwidth(tri) * 0.75 + 0.0001;
	float sw = clamp(softness, 0.0, 1.0) * 0.5;
	float w = smoothstep(0.5 - sw - aa, 0.5 + sw + aa, tri);
	vec3 gen = mix(colour_a.rgb, colour_b.rgb, w);
	float center_fade = smoothstep(0.0, 0.08, r);
	gen = mix(mix(colour_a.rgb, colour_b.rgb, 0.5), gen, center_fade);
	gen += (vec3(1.0) - gen) * clamp(glow, 0.0, 1.0) * exp(-r * r * 10.0);
	gen *= 1.0 - 0.25 * smoothstep(0.35, 1.3, r);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	COLOR = mix_in(rgb, c.a, gen, 1.0, blend, strength);
}
