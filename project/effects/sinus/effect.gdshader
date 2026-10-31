shader_type canvas_item;
render_mode blend_disabled;

uniform float x_scale : hint_range(0.1, 100.0) = 15.0;
uniform float y_scale : hint_range(0.1, 100.0) = 15.0;
uniform float complexity : hint_range(0.0, 15.0) = 4.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform bool tiling = false;
uniform bool distorted = false;
uniform vec4 colour_a : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform vec4 colour_b : source_color = vec4(0.0, 0.0, 1.0, 1.0);
uniform int colour_blend : hint_range(0, 2) = 2;
uniform float exponent : hint_range(-7.5, 7.5) = 0.0;
uniform int blend : hint_range(0, 6) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

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

float rnd(int k) {
	vec3 p3 = fract(vec3(float(k) * 12.9898 + float(seed) * 78.233 + 0.17) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float freq(int k, float span, float gain) {
	float f = (rnd(k) * 2.0 - 1.0) * 3.14159265 * gain;
	if (tiling) {
		f = round(f * span / 6.2831853) * 6.2831853 / max(span, 0.0001);
	}
	return f;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 p = UV * vec2(x_scale, y_scale);
	float cx = clamp(complexity, 0.0, 15.0);
	float g3 = 0.25 + cx * 0.25;
	float c11 = freq(1, x_scale, 1.0);
	float c12 = freq(2, y_scale, 1.0);
	float c21 = freq(4, x_scale, 1.0);
	float c22 = freq(5, y_scale, 1.0);
	float c31 = freq(7, x_scale, g3);
	float c32 = freq(8, y_scale, g3);
	float c13 = rnd(3) * 6.2831853;
	float c23 = rnd(6) * 6.2831853;
	float c33 = rnd(9) * 6.2831853;
	if (distorted) {
		p += vec2(sin(p.y * 0.9 + c13), sin(p.x * 0.8 + c23)) * 0.6;
	}
	float mixer = sin(c31 * p.x + c32 * p.y + c33);
	float grey = sin(c11 * p.x + c12 * p.y + c13) * (0.5 + 0.5 * mixer) + sin(c21 * p.x + c22 * p.y + c23) * (0.5 - 0.5 * mixer);
	if (cx > 1.0) {
		grey = sin(grey * (1.0 + (cx - 1.0) * 0.35) * 1.5707963);
	}
	float t = clamp(0.5 + 0.5 * grey, 0.0, 1.0);
	if (colour_blend == 1) {
		t = abs(2.0 * t - 1.0);
	} else if (colour_blend == 2) {
		t = 0.5 - 0.5 * cos(3.14159265 * t);
	}
	t = pow(t, exp(clamp(exponent, -7.5, 7.5)));
	vec4 pa = vec4(colour_a.rgb * colour_a.a, colour_a.a);
	vec4 pb = vec4(colour_b.rgb * colour_b.a, colour_b.a);
	vec4 pm = mix(pa, pb, t);
	vec3 gen = pm.a > 0.0001 ? pm.rgb / pm.a : vec3(0.0);
	COLOR = mix_in(rgb, a, gen, pm.a, blend, strength);
}
