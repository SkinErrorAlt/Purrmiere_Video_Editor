shader_type canvas_item;
render_mode blend_disabled;

uniform float vein : hint_range(8.0, 1000.0) = 220.0;
uniform float turbulence : hint_range(0.0, 10.0) = 4.0;
uniform int detail : hint_range(1, 8) = 5;
uniform float sharpness : hint_range(0.0, 1.0) = 0.6;
uniform float angle : hint_range(-180.0, 180.0) = 30.0;
uniform vec4 base_colour : source_color = vec4(0.93, 0.91, 0.87, 1.0);
uniform vec4 vein_colour : source_color = vec4(0.26, 0.26, 0.3, 1.0);
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
	vec3 p3 = fract(vec3(p.xyx) * 0.1031 + float(seed) * 0.0179);
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

float turb(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= detail) {
			break;
		}
		v += amp * abs(vnoise(p) * 2.0 - 1.0);
		norm += amp;
		p = p * 2.07 + vec2(13.7, 31.1);
		amp *= 0.5;
	}
	return v / max(norm, 0.0001);
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
	float vs = max(vein, 1.0);
	float tb = clamp(turbulence, 0.0, 10.0);
	float swirl = (vnoise(p / (vs * 3.0) + 17.0) - 0.5) * 2.0;
	float t = sin(3.14159265 * (p.x / vs + tb * 0.35 * turb(p / (vs * 1.4)) + tb * 0.3 * swirl));
	float m = pow(1.0 - abs(t), mix(1.0, 14.0, clamp(sharpness, 0.0, 1.0)));
	float cloud = (vnoise(p / (vs * 0.6) + 50.0) - 0.5) * 0.12 * clamp(tb, 0.0, 1.0);
	vec3 stone = mix(base_colour.rgb * (1.0 + cloud), vein_colour.rgb, clamp(m, 0.0, 1.0));
	COLOR = mix_in(rgb, a, stone, 1.0, blend, strength);
}
