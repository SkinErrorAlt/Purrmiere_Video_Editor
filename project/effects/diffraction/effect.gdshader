shader_type canvas_item;
render_mode blend_disabled;

uniform float red_frequency : hint_range(0.0, 20.0) = 0.815;
uniform float green_frequency : hint_range(0.0, 20.0) = 1.221;
uniform float blue_frequency : hint_range(0.0, 20.0) = 1.123;
uniform float red_contours : hint_range(0.0, 10.0) = 0.821;
uniform float green_contours : hint_range(0.0, 10.0) = 0.821;
uniform float blue_contours : hint_range(0.0, 10.0) = 0.974;
uniform float red_edges : hint_range(0.0, 1.0) = 0.61;
uniform float green_edges : hint_range(0.0, 1.0) = 0.677;
uniform float blue_edges : hint_range(0.0, 1.0) = 0.636;
uniform float brightness : hint_range(0.0, 1.0) = 0.066;
uniform float scattering : hint_range(0.0, 100.0) = 37.126;
uniform float polarization : hint_range(-1.0, 1.0) = -0.473;
uniform float zoom : hint_range(0.1, 10.0) = 1.0;
uniform int blend : hint_range(0, 6) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);

const int ITERATIONS = 100;
const float WEIRD_FACTOR = 0.04;

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

vec3 intensity(vec2 p) {
	vec3 lam = 4.0 * vec3(red_frequency, green_frequency, blue_frequency);
	vec3 cxy = vec3(0.0);
	vec3 sxy = vec3(0.0);
	float step_a = 6.2831853 / float(ITERATIONS);
	vec2 rot = vec2(cos(step_a), sin(step_a));
	vec2 cs = vec2(-1.0, 0.0);
	for (int i = 0; i <= ITERATIONS; i++) {
		float base = cs.x * p.x + 0.75 * cs.y * p.y - 0.5 * (4.0 * cs.x * cs.x + cs.y * cs.y);
		vec3 ph = lam * base;
		cxy += cos(ph);
		sxy += sin(ph);
		cs = vec2(cs.x * rot.x - cs.y * rot.y, cs.x * rot.y + cs.y * rot.x);
	}
	cxy *= WEIRD_FACTOR;
	sxy *= WEIRD_FACTOR;
	float pol = polarization * 1.5707963;
	float cp = cos(pol);
	float sp = sin(pol);
	return scattering * ((cp + sp) * cxy * cxy + (cp - sp) * sxy * sxy);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	vec2 p = (UV - 0.5) * vec2(sz.x / sz.y, 1.0) * 10.0 / max(zoom, 0.01);
	p.y = -p.y;
	vec3 inten = intensity(p);
	vec3 edges = vec3(red_edges, green_edges, blue_edges);
	vec3 contours = vec3(red_contours, green_contours, blue_contours);
	vec3 gen = abs(edges * sin(contours * atan(brightness * inten)));
	COLOR = mix_in(rgb, a, gen, 1.0, blend, strength);
}
