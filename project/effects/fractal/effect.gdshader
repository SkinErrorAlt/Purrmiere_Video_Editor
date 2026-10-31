shader_type canvas_item;
render_mode blend_disabled;

uniform int set_type : hint_range(0, 3) = 0;
uniform float centre_x : hint_range(-3.0, 3.0) = -0.65;
uniform float centre_y : hint_range(-3.0, 3.0) = 0.0;
uniform float zoom : hint_range(-2.0, 16.0) = 0.0;
uniform float julia_x : hint_range(-2.0, 2.0) = -0.8;
uniform float julia_y : hint_range(-2.0, 2.0) = 0.156;
uniform int iterations : hint_range(8, 500) = 128;
uniform int palette : hint_range(0, 3) = 2;
uniform vec4 colour : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float cycle : hint_range(1.0, 200.0) = 10.0;
uniform float cycle_offset : hint_range(0.0, 360.0) = 0.0;
uniform vec4 inside : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool smooth_edges = true;
uniform int blend : hint_range(0, 6) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);

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

vec3 hue(float h) {
	return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

vec3 band_colour(float n) {
	float x = n / max(cycle, 1.0) + cycle_offset / 360.0;
	if (palette == 0) {
		float v = 0.5 - 0.5 * cos(6.2831853 * x);
		return mix(colour.rgb * 0.08, mix(colour.rgb, vec3(1.0), 0.35), v);
	}
	if (palette == 1) {
		return mix(vec3(1.0), hue(fract(x)), 0.85);
	}
	if (palette == 3) {
		float v = 0.5 - 0.5 * cos(6.2831853 * x);
		return clamp(vec3(v * 1.6, v * v * 1.2, v * v * v * 0.9), 0.0, 1.0);
	}
	return 0.5 + 0.5 * cos(6.2831853 * (vec3(x) + vec3(0.0, 0.33, 0.67)));
}

vec4 shade_point(vec2 p) {
	if (set_type == 1 || set_type == 3) {
		float d = dot(p, p);
		p = d > 1.0e-12 ? vec2(p.x, -p.y) / d : vec2(1.0e6, 0.0);
	}
	vec2 z;
	vec2 c;
	if (set_type >= 2) {
		z = p;
		c = vec2(julia_x, julia_y);
	} else {
		z = vec2(0.0);
		c = p;
	}
	int limit = clamp(iterations, 8, 500);
	int esc = -1;
	for (int i = 0; i < 500; i++) {
		if (i >= limit) {
			break;
		}
		z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
		if (dot(z, z) > 256.0) {
			esc = i;
			break;
		}
	}
	if (esc < 0) {
		return vec4(inside.rgb, 1.0);
	}
	float nu = float(esc) + 1.0 - log2(log2(dot(z, z)) * 0.5);
	return vec4(band_colour(max(nu, 0.0)), 1.0);
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float a = src.a;
	vec3 rgb = a > 0.0001 ? src.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	float h = 3.0 / exp2(clamp(zoom, -2.0, 16.0));
	vec2 unit = vec2(h * sz.x / sz.y, h);
	vec2 centre = vec2(centre_x, centre_y);
	vec3 gen = vec3(0.0);
	if (smooth_edges) {
		vec2 px = unit / sz;
		for (int j = 0; j < 2; j++) {
			for (int i = 0; i < 2; i++) {
				vec2 o = (vec2(float(i), float(j)) - 0.5) * 0.5 * px;
				gen += shade_point(centre + (UV - 0.5) * unit + o).rgb;
			}
		}
		gen *= 0.25;
	} else {
		gen = shade_point(centre + (UV - 0.5) * unit).rgb;
	}
	COLOR = mix_in(rgb, a, gen, 1.0, blend, strength);
}
