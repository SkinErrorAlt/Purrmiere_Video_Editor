shader_type canvas_item;
render_mode blend_disabled;

uniform float ring : hint_range(4.0, 400.0) = 22.0;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform float distortion : hint_range(0.0, 2.0) = 0.6;
uniform float fine : hint_range(0.0, 1.0) = 0.5;
uniform float knots : hint_range(0.0, 1.0) = 0.3;
uniform vec4 light : source_color = vec4(0.84, 0.62, 0.4, 1.0);
uniform vec4 dark : source_color = vec4(0.48, 0.28, 0.14, 1.0);
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
	vec3 p3 = fract(vec3(p.xyx) * 0.1031 + float(seed) * 0.0213);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		amp *= 0.5;
	}
	return v / 0.9375;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float rad = radians(angle);
	vec2 d = (UV * sz - 0.5 * sz) / ps;
	vec2 p = vec2(cos(rad) * d.x + sin(rad) * d.y, -sin(rad) * d.x + cos(rad) * d.y);
	float rs = max(ring, 1.0);
	float w = p.y / rs;
	w += clamp(distortion, 0.0, 2.0) * (fbm(p * vec2(1.0 / (rs * 18.0), 1.0 / (rs * 5.0))) - 0.5) * 4.0;
	w += clamp(distortion, 0.0, 2.0) * 0.6 * sin(p.x / (rs * 9.0) + hash12(vec2(3.0, 7.0)) * 6.28);
	float kn = clamp(knots, 0.0, 1.0);
	if (kn > 0.0) {
		vec2 cell_size = vec2(rs * 14.0, rs * 6.0);
		vec2 base = floor(p / cell_size);
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 id = base + vec2(float(i), float(j));
				if (hash12(id + 41.0) < kn) {
					vec2 kc = (id + vec2(0.2, 0.2) + 0.6 * vec2(hash12(id + 5.0), hash12(id + 9.0))) * cell_size;
					vec2 e = (p - kc) / vec2(rs * 2.2, rs * 1.1);
					float r2 = dot(e, e);
					w += (hash12(id + 13.0) < 0.5 ? -1.0 : 1.0) * 2.5 * exp(-r2 * 0.6);
				}
			}
		}
	}
	float f = fract(w);
	float late = smoothstep(0.55, 0.92, f) * (1.0 - smoothstep(0.94, 1.0, f));
	float early = 0.25 * f;
	float streak = vnoise(p * vec2(1.0 / (rs * 6.0), 1.0 / max(rs * 0.07, 0.6))) - 0.5;
	float pores = vnoise(p * vec2(0.08, 0.9)) - 0.5;
	float tone = clamp(early + 0.75 * late + clamp(fine, 0.0, 1.0) * (0.35 * streak + 0.15 * pores), 0.0, 1.0);
	vec3 wood = mix(light.rgb, dark.rgb, tone);
	COLOR = mix_in(rgb, a, wood, 1.0, blend, strength);
}
