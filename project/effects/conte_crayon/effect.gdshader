shader_type canvas_item;
render_mode blend_disabled;

uniform float fg_level : hint_range(1.0, 15.0) = 11.0;
uniform float bg_level : hint_range(1.0, 15.0) = 7.0;
uniform int texture_kind : hint_range(0, 3) = 2;
uniform float scaling : hint_range(50.0, 200.0) = 100.0;
uniform float relief : hint_range(0.0, 50.0) = 4.0;
uniform float light_angle : hint_range(-180.0, 180.0) = 90.0;
uniform vec4 fg_colour : source_color = vec4(0.17, 0.09, 0.07, 1.0);
uniform vec4 bg_colour : source_color = vec4(0.97, 0.95, 0.9, 1.0);
uniform vec4 paper : source_color = vec4(0.66, 0.58, 0.48, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 seed_offset(int s) {
	float f = float(s);
	return vec2(mod(f * 12.9898, 997.0), mod(f * 78.233, 991.0));
}

float weave(vec2 p, float period) {
	vec2 q = p / period;
	vec2 cell = floor(q);
	vec2 f = fract(q);
	float hor = sin(f.y * 3.14159) * (0.55 + 0.45 * sin(f.x * 3.14159));
	float ver = sin(f.x * 3.14159) * (0.55 + 0.45 * sin(f.y * 3.14159));
	return mod(cell.x + cell.y, 2.0) < 1.0 ? hor : ver;
}

float surface(vec2 p, int kind) {
	if (kind == 0) {
		vec2 b = vec2(46.0, 20.0);
		float row = floor(p.y / b.y);
		vec2 f = fract(vec2(p.x / b.x + 0.5 * mod(row, 2.0), p.y / b.y)) * b;
		float m = min(min(f.x, b.x - f.x), min(f.y, b.y - f.y));
		return smoothstep(0.5, 3.5, m) * (0.7 + 0.3 * value_noise(p / 2.5));
	}
	if (kind == 1) {
		vec2 wob = vec2(value_noise(p / 11.0), value_noise(p / 11.0 + 5.2)) * 2.5;
		return weave(p + wob, 8.0) * (0.7 + 0.3 * value_noise(p / 1.8));
	}
	if (kind == 2) {
		return weave(p, 3.2) * 0.8 + value_noise(p / 1.4) * 0.2;
	}
	return value_noise(p / 1.4) * 0.5 + value_noise(p / 4.0) * 0.3 + value_noise(p / 13.0) * 0.2;
}

float lum(vec4 c) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	return dot(rgb, vec3(0.2126, 0.7152, 0.0722));
}

float cover(float amount, float tex) {
	return clamp((amount * 1.35 - (1.0 - tex)) * 3.0, 0.0, 1.0);
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec2 so = seed_offset(seed);
	vec2 e = vec2(1.5 * ps) / dims;
	float tone = lum(c) * 0.4 + (lum(texture(TEXTURE, UV + vec2(e.x, 0.0))) + lum(texture(TEXTURE, UV - vec2(e.x, 0.0))) + lum(texture(TEXTURE, UV + vec2(0.0, e.y))) + lum(texture(TEXTURE, UV - vec2(0.0, e.y)))) * 0.15;
	vec2 pix = UV * dims / ps;
	vec2 p = pix / max(scaling / 100.0, 0.01) + so;
	float ang = radians(light_angle);
	vec2 ld = vec2(cos(ang), -sin(ang));
	float h = surface(p, texture_kind);
	float shade = (surface(p + ld, texture_kind) - surface(p - ld, texture_kind)) * relief / 50.0 * 1.6;
	vec2 sd = vec2(cos(1.1), -sin(1.1));
	float grain = value_noise(vec2(dot(pix, sd) / 14.0, dot(pix, vec2(-sd.y, sd.x)) / 1.6) + so.yx);
	float tex = h * 0.7 + grain * 0.3;
	float thr_d = fg_level / 15.0 * 0.55;
	float thr_l = 1.0 - bg_level / 15.0 * 0.55;
	float dark = cover(smoothstep(thr_d + 0.2, thr_d - 0.25, tone), tex);
	float light = cover(smoothstep(thr_l - 0.2, thr_l + 0.25, tone), tex);
	vec3 outc = mix(paper.rgb, bg_colour.rgb, light);
	outc = mix(outc, fg_colour.rgb, dark);
	outc *= 1.0 + shade + (h - 0.5) * 0.06;
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
