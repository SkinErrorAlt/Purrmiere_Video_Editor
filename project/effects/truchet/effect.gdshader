shader_type canvas_item;
render_mode blend_disabled;

uniform float tile : hint_range(4.0, 1000.0) = 48.0;
uniform int style : hint_range(0, 3) = 0;
uniform float line : hint_range(0.5, 200.0) = 6.0;
uniform vec4 colour_a : source_color = vec4(0.95, 0.92, 0.85, 1.0);
uniform vec4 colour_b : source_color = vec4(0.12, 0.14, 0.2, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform int blend : hint_range(0, 6) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

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

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031 + float(seed) * 0.0137);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float t = max(tile * ps, 2.0);
	vec2 p = UV * sz;
	vec2 cell = floor(p / t);
	vec2 f = p / t - cell;
	bool flip = hash12(cell + 0.5) < 0.5;
	if (flip) {
		f.x = 1.0 - f.x;
	}
	float aa = 0.75 / t;
	float half_w = 0.5 * line * ps / t;
	float cover = 0.0;
	if (style == 0) {
		float d = min(abs(length(f) - 0.5), abs(length(f - 1.0) - 0.5));
		cover = 1.0 - smoothstep(half_w - aa, half_w + aa, d);
	} else if (style == 1) {
		float sd = min(length(f) - 0.5, length(f - 1.0) - 0.5);
		cover = 1.0 - smoothstep(-aa, aa, sd);
		bool odd = mod(cell.x + cell.y, 2.0) > 0.5;
		if (odd != flip) {
			cover = 1.0 - cover;
		}
	} else if (style == 2) {
		float d = abs(f.x - f.y) * 0.70710678;
		cover = 1.0 - smoothstep(half_w - aa, half_w + aa, d);
	} else {
		float sd = (f.y - f.x) * 0.70710678;
		cover = 1.0 - smoothstep(-aa, aa, sd);
	}
	vec4 pa = vec4(colour_a.rgb * colour_a.a, colour_a.a);
	vec4 pb = vec4(colour_b.rgb * colour_b.a, colour_b.a);
	vec4 pm = mix(pb, pa, cover);
	vec3 gen = pm.a > 0.0001 ? pm.rgb / pm.a : vec3(0.0);
	COLOR = mix_in(rgb, a, gen, pm.a, blend, strength);
}
