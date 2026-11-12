shader_type canvas_item;
render_mode blend_disabled;

uniform int paper = 0;
uniform float exposure : hint_range(0.0, 2.0) = 1.0;
uniform float bleed : hint_range(0.0, 1.0) = 0.5;
uniform float blooms : hint_range(0.0, 1.0) = 0.5;
uniform float unevenness : hint_range(0.0, 1.0) = 0.5;
uniform float grain : hint_range(0.0, 1.0) = 0.5;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p = p * 2.02 + vec2(13.7, 7.3);
		a *= 0.5;
	}
	return s;
}

vec3 ramp4(vec3 a, vec3 b, vec3 c, vec3 d, float t) {
	t = clamp(t, 0.0, 1.0) * 3.0;
	if (t < 1.0) {
		return mix(a, b, smoothstep(0.0, 1.0, t));
	}
	if (t < 2.0) {
		return mix(b, c, smoothstep(0.0, 1.0, t - 1.0));
	}
	return mix(c, d, smoothstep(0.0, 1.0, t - 2.0));
}

vec3 paper_colour(float d) {
	if (paper == 1) {
		return ramp4(vec3(0.95, 0.94, 0.8), vec3(0.76, 0.8, 0.66), vec3(0.45, 0.5, 0.6), vec3(0.24, 0.2, 0.34), d);
	}
	if (paper == 2) {
		return ramp4(vec3(0.93, 0.84, 0.62), vec3(0.84, 0.6, 0.4), vec3(0.52, 0.34, 0.26), vec3(0.24, 0.17, 0.15), d);
	}
	if (paper == 3) {
		return ramp4(vec3(0.96, 0.92, 0.9), vec3(0.83, 0.7, 0.78), vec3(0.5, 0.42, 0.6), vec3(0.2, 0.2, 0.32), d);
	}
	return ramp4(vec3(0.97, 0.91, 0.83), vec3(0.93, 0.7, 0.6), vec3(0.62, 0.37, 0.42), vec3(0.3, 0.19, 0.24), d);
}

float lum_at(sampler2D tex, vec2 uv) {
	vec4 c = texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
	return dot(c.rgb / max(c.a, 0.0001), vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float ps = max(px_scale, 0.0001);
	vec2 p = UV * tex_size / ps;
	vec2 to_uv = ps / tex_size;
	vec2 so = vec2(float(seed) * 3.71, float(seed) * 1.93);
	float l = lum_at(TEXTURE, UV);
	float lb = 0.0;
	float wsum = 0.0;
	for (int i = 0; i < 12; i++) {
		float a = float(i) * 2.39996;
		float r = 3.0 + 1.6 * float(i);
		vec2 o = vec2(cos(a), sin(a)) * r;
		float w = 1.0 / (1.0 + 0.08 * r);
		lb += lum_at(TEXTURE, UV + o * to_uv) * w;
		wsum += w;
	}
	lb /= wsum;
	float d = 1.0 - l;
	float db = 1.0 - lb;
	d = mix(d, max(d, db * 0.95), bleed * 0.8);
	float sun = fbm(p * 0.0012 + so) - 0.5;
	float patch = fbm(p * 0.006 + so * 1.3) - 0.5;
	float e = exposure * (1.0 + unevenness * (sun * 0.9 + patch * 0.5));
	float dd = smoothstep(0.06, 0.94, d);
	float dens = 1.0 - exp(-dd * 2.6 * e);
	dens = dens / max(1.0 - exp(-2.6 * max(e, 0.05)), 0.05);
	dens = clamp(dens, 0.0, 1.0);
	vec3 col = paper_colour(dens);
	vec2 w1 = vec2(fbm(p * 0.004 + so + 5.0), fbm(p * 0.004 + so + 9.0)) - 0.5;
	float bloomf = fbm(p * 0.0035 + w1 * 1.6 + so * 2.0);
	float bl = smoothstep(0.56, 0.72, bloomf) * blooms;
	float rim = (smoothstep(0.54, 0.57, bloomf) - smoothstep(0.57, 0.64, bloomf)) * blooms * 0.6;
	vec3 tintc = paper == 1 ? vec3(0.95, 0.86, 0.55) : (paper == 2 ? vec3(0.7, 0.72, 0.5) : vec3(0.78, 0.82, 0.62));
	col = mix(col, col * tintc * 1.12, bl * (0.35 + 0.65 * dens));
	col = mix(col, col * vec3(0.72, 0.62, 0.62), rim * 0.8);
	float g1 = vnoise(p * 0.55 + so) - 0.5;
	float g2 = vnoise(p * 0.17 + so) - 0.5;
	col *= 1.0 + grain * (g1 * 0.07 + g2 * 0.06);
	float dust = step(0.9965, h12(floor(p * 0.5) + so));
	col = mix(col, paper_colour(0.0), dust * grain * 0.9);
	COLOR = vec4(clamp(col, 0.0, 1.0) * base.a, base.a);
}
