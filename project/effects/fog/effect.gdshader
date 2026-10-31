shader_type canvas_item;
render_mode blend_disabled;

uniform float density : hint_range(0.0, 1.0) = 0.6;
uniform float height_falloff : hint_range(0.0, 1.0) = 0.6;
uniform vec2 drift = vec2(0.03, 0.0);
uniform float churn : hint_range(0.0, 2.0) = 0.15;
uniform float scale : hint_range(0.1, 10.0) = 1.0;
uniform vec4 colour : source_color = vec4(0.86, 0.88, 0.92, 1.0);
uniform int detail : hint_range(1, 8) = 5;
uniform int blend : hint_range(0, 6) = 6;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	float total = 0.0;
	vec2 q = p;
	for (int i = 0; i < 8; i++) {
		if (i >= octaves) { break; }
		sum += value_noise(q) * amp;
		total += amp;
		q = q * 2.03 + vec2(17.1, 9.2);
		amp *= 0.5;
	}
	return total > 0.0 ? sum / total : 0.0;
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
	float k = 3.0 / max(scale, 0.01);
	vec2 pos = UV * vec2(sz.x / sz.y, 1.0) * k;
	vec2 mv = drift * clip_time * k;
	float ch = clip_time * churn;
	vec2 wv = vec2(fbm(pos * 0.5 - mv * 0.5 + vec2(ch * 0.3, 1.7), 3), fbm(pos * 0.5 - mv * 0.5 + vec2(5.2, 1.3 - ch * 0.2), 3));
	float n = fbm(pos - mv + (wv - 0.5) * 2.0 + vec2(ch * 0.15, -ch * 0.1), detail);
	float puffs = smoothstep(0.3, 0.75, n);
	float low = mix(1.0, smoothstep(-0.1, 1.0, UV.y), clamp(height_falloff, 0.0, 1.0));
	float cov = clamp(density * (0.3 + 0.9 * puffs) * low * 1.2, 0.0, 1.0) * colour.a;
	COLOR = mix_in(rgb, a, colour.rgb, cov, blend, strength);
}
