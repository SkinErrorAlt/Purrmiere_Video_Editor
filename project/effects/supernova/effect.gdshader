shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.62, 0.38);
uniform vec4 colour : source_color = vec4(0.35, 0.55, 1.0, 1.0);
uniform float radius : hint_range(1.0, 400.0) = 24.0;
uniform int spokes : hint_range(1, 1024) = 100;
uniform float random_hue : hint_range(0.0, 360.0) = 0.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float hash11(float p) {
	vec3 p3 = fract(vec3(p) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float rnd(int i, int k) {
	return hash11(float(i) * 7.31 + float(k) * 131.7 + float(seed) * 1013.3 + 0.5);
}

float spoke_strength(int i) {
	float s = 0.0;
	for (int k = 0; k < 6; k++) {
		s += rnd(i, k);
	}
	return s / 6.0;
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

vec3 spoke_colour(int i, vec3 hsv) {
	float h = hsv.x + (random_hue / 360.0) * (rnd(i, 7) - 0.5);
	return hsv2rgb(vec3(fract(h), hsv.y, hsv.z));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 src = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	float rad = max(radius * max(px_scale, 0.0001), 0.5);
	vec2 d = (UV - centre) * sz / rad;
	float l = length(d);
	int n = max(spokes, 1);
	float t = (atan(d.x, d.y) / 6.2831853 + 0.51) * float(n);
	int i = int(floor(t));
	t -= float(i);
	i = i % n;
	int j = (i + 1) % n;
	float w1 = spoke_strength(i) * (1.0 - t) + spoke_strength(j) * t;
	w1 = w1 * w1;
	float w = 1.0 / (l + 0.001) * 0.9;
	float nova = clamp(w, 0.0, 1.0);
	vec3 hsv = rgb2hsv(clamp(colour.rgb, 0.0, 1.0));
	vec3 sc = spoke_colour(i, hsv) * (1.0 - t) + spoke_colour(j, hsv) * t;
	float lift = clamp(w1 * w, 0.0, 1.0);
	vec3 lit;
	if (w > 1.0) {
		lit = clamp(sc * w, 0.0, 1.0);
	} else {
		lit = src * (1.0 - nova) + sc * nova;
	}
	lit = clamp(lit + lift, 0.0, 1.0);
	vec3 alone = clamp((w > 1.0 ? clamp(sc * w, 0.0, 1.0) : sc * nova) + lift, 0.0, 1.0);
	float alone_a = clamp(max(nova, lift), 0.0, 1.0);
	vec3 premult = lit * a + alone * alone_a * (1.0 - a);
	float out_a = a + alone_a * (1.0 - a);
	COLOR = vec4(min(premult, vec3(out_a)), out_a);
}
