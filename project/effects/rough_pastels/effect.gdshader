shader_type canvas_item;
render_mode blend_disabled;

uniform float stroke_length : hint_range(1.0, 60.0) = 18.0;
uniform float stroke_detail : hint_range(1.0, 20.0) = 4.0;
uniform int texture_kind : hint_range(0, 3) = 2;
uniform float scaling : hint_range(50.0, 200.0) = 100.0;
uniform float relief : hint_range(0.0, 50.0) = 20.0;
uniform float light_angle : hint_range(-180.0, 180.0) = 90.0;
uniform float angle : hint_range(-180.0, 180.0) = 45.0;
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

vec3 unpremul(vec4 c) {
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
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

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec2 so = seed_offset(seed);
	vec2 pix = UV * dims / ps;
	float len = max(stroke_length, 1.0);
	vec2 cell = floor(pix / max(len * 0.6, 1.0));
	float ang = radians(angle) + (hash12(cell + so) - 0.5) * 0.45;
	vec2 dir = vec2(cos(ang), -sin(ang));
	vec2 su = dir * len * ps / dims;
	vec3 sc = vec3(0.0);
	for (int i = -3; i <= 3; i++) {
		sc += unpremul(texture(TEXTURE, UV + su * float(i) / 6.0));
	}
	sc /= 7.0;
	sc = mix(sc, unpremul(c), clamp(stroke_detail / 20.0, 0.0, 1.0) * 0.6);
	float along = dot(pix, dir);
	float across = dot(pix, vec2(-dir.y, dir.x));
	float streak = value_noise(vec2(along / len * 1.5, across / 2.2) + so) * 0.7 + value_noise(vec2(along / 3.0, across / 0.8) + so.yx) * 0.3;
	vec2 tp = pix / max(scaling / 100.0, 0.01) + so;
	float lang = radians(light_angle);
	vec2 ld = vec2(cos(lang), -sin(lang));
	float h = surface(tp, texture_kind);
	float shade = (surface(tp + ld, texture_kind) - surface(tp - ld, texture_kind)) * relief / 50.0 * 0.9;
	float lum = dot(sc, vec3(0.2126, 0.7152, 0.0722));
	float amount = 0.3 + lum * 0.8;
	float tex = h * 0.45 + streak * 0.55;
	float cover = clamp((amount * 1.25 - (1.0 - tex)) * 3.0, 0.0, 1.0);
	vec3 chalk = (mix(vec3(lum), sc, 1.15) * 0.92 + 0.08) * (0.84 + 0.32 * streak);
	vec3 ground = sc * 0.38;
	vec3 outc = mix(ground, chalk, cover);
	outc *= 1.0 + shade * mix(1.0, 0.5, cover);
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
