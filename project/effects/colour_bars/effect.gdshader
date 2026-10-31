shader_type canvas_item;
render_mode blend_disabled;

uniform int pattern : hint_range(0, 4) = 0;
uniform int blend : hint_range(0, 6) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

const vec3 SMPTE_TOP[7] = vec3[7](vec3(0.753, 0.753, 0.753), vec3(0.753, 0.753, 0.0), vec3(0.0, 0.753, 0.753), vec3(0.0, 0.753, 0.0), vec3(0.753, 0.0, 0.753), vec3(0.753, 0.0, 0.0), vec3(0.0, 0.0, 0.753));
const vec3 SMPTE_MID[7] = vec3[7](vec3(0.0, 0.0, 0.753), vec3(0.075, 0.075, 0.075), vec3(0.753, 0.0, 0.753), vec3(0.075, 0.075, 0.075), vec3(0.0, 0.753, 0.753), vec3(0.075, 0.075, 0.075), vec3(0.753, 0.753, 0.753));
const vec3 BARS[8] = vec3[8](vec3(1.0, 1.0, 1.0), vec3(1.0, 1.0, 0.0), vec3(0.0, 1.0, 1.0), vec3(0.0, 1.0, 0.0), vec3(1.0, 0.0, 1.0), vec3(1.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0), vec3(0.0, 0.0, 0.0));

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

vec3 smpte_bottom(float u) {
	if (u < 5.0) { return vec3(0.0, 0.129, 0.298); }
	if (u < 10.0) { return vec3(1.0, 1.0, 1.0); }
	if (u < 15.0) { return vec3(0.196, 0.0, 0.416); }
	if (u < 20.0) { return vec3(0.075, 0.075, 0.075); }
	if (u < 20.0 + 4.0 / 3.0) { return vec3(0.035, 0.035, 0.035); }
	if (u < 20.0 + 8.0 / 3.0) { return vec3(0.075, 0.075, 0.075); }
	if (u < 24.0) { return vec3(0.114, 0.114, 0.114); }
	return vec3(0.075, 0.075, 0.075);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float x = clamp(UV.x, 0.0, 1.0);
	float y = clamp(UV.y, 0.0, 1.0);
	vec3 gen;
	if (pattern == 1) {
		int i = clamp(int(floor(x * 8.0)), 0, 7);
		gen = i == 0 ? vec3(1.0) : BARS[i] * 0.75;
	} else if (pattern == 2) {
		gen = BARS[clamp(int(floor(x * 8.0)), 0, 7)];
	} else if (pattern == 3) {
		gen = vec3(x);
	} else if (pattern == 4) {
		gen = vec3(clamp(floor(x * 11.0), 0.0, 10.0) / 10.0);
	} else {
		int i = clamp(int(floor(x * 7.0)), 0, 6);
		if (y < 2.0 / 3.0) {
			gen = SMPTE_TOP[i];
		} else if (y < 0.75) {
			gen = SMPTE_MID[i];
		} else {
			gen = smpte_bottom(x * 28.0);
		}
	}
	COLOR = mix_in(rgb, a, gen, 1.0, blend, strength);
}
