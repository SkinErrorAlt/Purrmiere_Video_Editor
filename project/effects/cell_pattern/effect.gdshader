shader_type canvas_item;
render_mode blend_disabled;

uniform int style : hint_range(0, 3) = 0;
uniform float size : hint_range(4.0, 2000.0) = 90.0;
uniform float jitter : hint_range(0.0, 1.0) = 0.9;
uniform float evolve : hint_range(0.0, 10.0) = 0.4;
uniform float contrast : hint_range(0.0, 4.0) = 1.0;
uniform vec4 colour_a : source_color = vec4(0.04, 0.07, 0.14, 1.0);
uniform vec4 colour_b : source_color = vec4(0.55, 0.8, 1.0, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform int blend : hint_range(0, 6) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

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
	float cell = max(size * ps, 2.0);
	vec2 g = UV * sz / cell;
	vec2 base = floor(g);
	vec2 f = g - base;
	vec2 skey = floor(hash22(vec2(float(seed) * 0.7123 + 3.1, 11.7)) * 997.0);
	float t = clip_time * evolve;
	float jit = clamp(jitter, 0.0, 1.0);
	float f1 = 8.0;
	float f2 = 8.0;
	vec2 near_id = base;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 o = vec2(float(i), float(j));
			vec2 cid = base + o;
			vec2 hc = hash22(cid + skey);
			vec2 wob = 0.5 + 0.5 * sin(vec2(t * (0.6 + hc.y), t * (0.5 + hc.x)) + 6.2831853 * hc);
			vec2 pt = 0.5 + jit * (wob - 0.5);
			float dd = length(o + pt - f);
			if (dd < f1) {
				f2 = f1;
				f1 = dd;
				near_id = cid;
			} else if (dd < f2) {
				f2 = dd;
			}
		}
	}
	float v;
	if (style == 1) {
		float aa = 1.5 / cell;
		v = 1.0 - smoothstep(0.02, 0.08 + aa, f2 - f1);
	} else if (style == 2) {
		float flat_v = hash12(near_id + skey + vec2(17.3, 5.1));
		v = flat_v * 0.85 + 0.15 * (1.0 - clamp(f1, 0.0, 1.0));
	} else if (style == 3) {
		float br = 0.3 + 0.18 * hash12(near_id + skey + vec2(3.7, 9.2));
		float x = clamp(f1 / br, 0.0, 1.0);
		float dome = sqrt(max(1.0 - x * x, 0.0));
		float aa = 1.5 / (cell * br);
		v = dome * (1.0 - smoothstep(1.0 - aa, 1.0, f1 / br));
	} else {
		v = clamp(f1, 0.0, 1.0);
	}
	v = clamp((v - 0.5) * contrast + 0.5, 0.0, 1.0);
	vec4 pa = vec4(colour_a.rgb * colour_a.a, colour_a.a);
	vec4 pb = vec4(colour_b.rgb * colour_b.a, colour_b.a);
	vec4 pm = mix(pa, pb, v);
	vec3 gen = pm.a > 0.0001 ? pm.rgb / pm.a : vec3(0.0);
	COLOR = mix_in(rgb, a, gen, pm.a, blend, strength);
}
