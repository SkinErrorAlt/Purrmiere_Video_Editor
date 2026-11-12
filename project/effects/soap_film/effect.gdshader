shader_type canvas_item;
render_mode blend_disabled;

uniform float thickness : hint_range(0.0, 1.0) = 0.45;
uniform float drain : hint_range(0.0, 1.0) = 0.45;
uniform float swirl : hint_range(0.0, 1.0) = 0.5;
uniform float flow : hint_range(0.0, 3.0) = 1.0;
uniform float swirl_size : hint_range(40.0, 1600.0) = 760.0;
uniform float colour : hint_range(0.0, 1.0) = 0.55;
uniform float lens : hint_range(0.0, 40.0) = 5.0;
uniform float gravity : hint_range(-180.0, 180.0) = 0.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 w = mod(i, 289.0);
	return mix(mix(hash12(w), hash12(w + vec2(1.0, 0.0)), f.x), mix(hash12(w + vec2(0.0, 1.0)), hash12(w + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm3(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		s += vnoise(p) * a;
		p = mat2(vec2(1.6, -1.2), vec2(1.2, 1.6)) * p + vec2(5.1, 1.7);
		a *= 0.5;
	}
	return s / 0.875;
}

float stream(vec2 p, float t) {
	return fbm3(p + vec2(t * 0.11, -t * 0.07)) + 0.5 * vnoise(p * 2.3 - vec2(t * 0.19, t * 0.05));
}

vec2 curl(vec2 p, float t) {
	float e = 0.05;
	float dx = stream(p + vec2(e, 0.0), t) - stream(p - vec2(e, 0.0), t);
	float dy = stream(p + vec2(0.0, e), t) - stream(p - vec2(0.0, e), t);
	return vec2(dy, -dx) / (2.0 * e);
}

vec3 cie_xyz(float l) {
	float t1 = (l - 442.0) * (l < 442.0 ? 0.0624 : 0.0374);
	float t2 = (l - 599.8) * (l < 599.8 ? 0.0264 : 0.0323);
	float t3 = (l - 501.1) * (l < 501.1 ? 0.0490 : 0.0382);
	float x = 0.362 * exp(-0.5 * t1 * t1) + 1.056 * exp(-0.5 * t2 * t2) - 0.065 * exp(-0.5 * t3 * t3);
	float y1 = (l - 568.8) * (l < 568.8 ? 0.0213 : 0.0247);
	float y2 = (l - 530.9) * (l < 530.9 ? 0.0613 : 0.0322);
	float y = 0.821 * exp(-0.5 * y1 * y1) + 0.286 * exp(-0.5 * y2 * y2);
	float z1 = (l - 437.0) * (l < 437.0 ? 0.0845 : 0.0278);
	float z2 = (l - 459.0) * (l < 459.0 ? 0.0385 : 0.0725);
	float z = 1.217 * exp(-0.5 * z1 * z1) + 0.681 * exp(-0.5 * z2 * z2);
	return vec3(x, y, z);
}

vec3 xyz_to_rgb(vec3 c) {
	return vec3(
		3.2406 * c.x - 1.5372 * c.y - 0.4986 * c.z,
		-0.9689 * c.x + 1.8758 * c.y + 0.0415 * c.z,
		0.0557 * c.x - 0.2040 * c.y + 1.0570 * c.z);
}

vec3 film_colour(float d) {
	vec3 acc = vec3(0.0);
	vec3 white = vec3(0.0);
	for (int i = 0; i < 12; i++) {
		float l = 400.0 + (float(i) + 0.5) * 25.0;
		vec3 m = cie_xyz(l);
		float s = sin(6.2831853 * 1.333 * d / l);
		acc += m * s * s;
		white += m;
	}
	vec3 rgb = xyz_to_rgb(acc / max(white.y, 0.0001));
	return max(rgb, vec3(0.0));
}

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 pix = UV * sz;
	float sk = mod(float(seed), 997.0);
	vec2 so = vec2(sk * 0.731 + 3.0, sk * 0.377 + 11.0);
	float t = max(clip_time, 0.0) * flow;
	float ga = radians(gravity);
	mat2 rot = mat2(vec2(cos(ga), sin(ga)), vec2(-sin(ga), cos(ga)));
	vec2 cen = UV - 0.5;
	vec2 gv = rot * (cen * vec2(sz.x / sz.y, 1.0));
	float y01 = clamp(gv.y + 0.5, 0.0, 1.0);
	vec2 p = pix / max(swirl_size * ps, 1.0) + so;
	vec2 q = p;
	float amp = swirl * 0.16;
	for (int i = 0; i < 6; i++) {
		q -= curl(q, t) * amp;
	}
	vec2 dq = (q - p) * max(swirl_size * ps, 1.0) / sz.y;
	float yq = y01 + (rot * dq).y * 1.6;
	float black = drain * 0.32;
	float yy = clamp((yq - black) / max(1.0 - black, 0.05), 0.0, 1.2);
	float dmax = mix(160.0, 1500.0, thickness);
	float expo = mix(0.55, 1.6, drain);
	float d = dmax * pow(yy, expo);
	float plume = fbm3(q * vec2(2.4, 0.9) + vec2(0.0, t * 0.35) + 31.0);
	d *= 1.0 - swirl * 0.35 * smoothstep(0.45, 0.85, plume) * smoothstep(0.25, 0.9, yy);
	d += (fbm3(q * 3.1 + 7.0) - 0.5) * 60.0 * swirl * smoothstep(0.0, 0.2, yy);
	d = max(d, 0.0);
	vec3 film = film_colour(d);
	float e = 1.5;
	vec2 grad = vec2(dFdx(d), dFdy(d));
	vec2 off = clamp(grad / e, vec2(-40.0), vec2(40.0)) * lens * ps * 0.06;
	vec4 c = texture(TEXTURE, clamp((pix + off) / sz, vec2(0.0), vec2(1.0)));
	vec4 base = texture(TEXTURE, UV);
	float a = base.a;
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	float k = clamp(colour, 0.0, 1.0);
	float refl = dot(film, vec3(0.2126, 0.7152, 0.0722));
	vec3 trans = rgb * (1.0 - k * 0.5 * clamp(refl, 0.0, 1.0));
	vec3 lit = 1.0 - (1.0 - trans) * (1.0 - clamp(film * k * 0.62, 0.0, 1.0));
	COLOR = vec4(clamp(lit, 0.0, 1.0) * a, a);
}
