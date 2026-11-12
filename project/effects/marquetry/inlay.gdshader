shader_type canvas_item;
render_mode blend_disabled;

uniform int woods = 0;
uniform int pieces : hint_range(2, 6) = 5;
uniform float contrast : hint_range(0.5, 2.5) = 1.2;
uniform float piece_size : hint_range(40.0, 600.0) = 220.0;
uniform float grain_scale : hint_range(0.25, 4.0) = 1.0;
uniform float sand_shading : hint_range(0.0, 1.0) = 0.6;
uniform float gloss : hint_range(0.0, 1.0) = 0.5;
uniform float light_angle : hint_range(-180.0, 180.0) = -50.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform sampler2D effect_tex : filter_linear, repeat_disable;

float h12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 h22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
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
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.01 + vec2(7.7, 3.1);
		a *= 0.5;
	}
	return s;
}

vec3 species(int k, int n) {
	float t = float(k) / float(max(n - 1, 1));
	if (woods == 1) {
		vec3 c0 = vec3(0.1, 0.08, 0.07);
		vec3 c1 = vec3(0.42, 0.18, 0.28);
		vec3 c2 = vec3(0.7, 0.27, 0.14);
		vec3 c3 = vec3(0.86, 0.68, 0.26);
		vec3 c4 = vec3(0.93, 0.89, 0.8);
		float s = t * 4.0;
		return s < 1.0 ? mix(c0, c1, s) : (s < 2.0 ? mix(c1, c2, s - 1.0) : (s < 3.0 ? mix(c2, c3, s - 2.0) : mix(c3, c4, s - 3.0)));
	}
	vec3 d0 = vec3(0.2, 0.13, 0.09);
	vec3 d1 = vec3(0.4, 0.26, 0.16);
	vec3 d2 = vec3(0.6, 0.35, 0.2);
	vec3 d3 = vec3(0.74, 0.56, 0.35);
	vec3 d4 = vec3(0.92, 0.85, 0.7);
	float s2 = t * 4.0;
	return s2 < 1.0 ? mix(d0, d1, s2) : (s2 < 2.0 ? mix(d1, d2, s2 - 1.0) : (s2 < 3.0 ? mix(d2, d3, s2 - 2.0) : mix(d3, d4, s2 - 3.0)));
}

float level_t(sampler2D tex, vec2 uv) {
	vec4 c = texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
	float l = dot(c.rgb / max(c.a, 0.0001), vec3(0.2126, 0.7152, 0.0722));
	l = clamp((l - 0.5) * contrast + 0.5, 0.0, 1.0);
	return l * float(pieces) * 0.999;
}

vec2 piece_cell(vec2 p, vec2 so, out float edge) {
	vec2 g = p / max(piece_size, 1.0);
	vec2 gi = floor(g);
	float d1 = 9.0;
	float d2 = 9.0;
	vec2 id = gi;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = gi + vec2(float(x), float(y));
			vec2 s = o + 0.15 + 0.7 * h22(o + so);
			float d = distance(g, s);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = o;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	edge = (d2 - d1) * max(piece_size, 1.0);
	return id;
}

void fragment() {
	vec4 base = texture(effect_tex, UV);
	vec2 out_size = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float ps = max(px_scale * out_size.x / max(tex_size.x, 1.0), 0.0001);
	vec2 p = UV * out_size / ps;
	vec2 to_uv = ps / out_size;
	vec2 so = vec2(float(seed) * 1.91, float(seed) * 4.37);
	int n = clamp(pieces, 2, 6);
	float t = level_t(TEXTURE, UV);
	int k = int(floor(t));
	float near = 0.0;
	float seam = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec2 o = vec2(cos(a), sin(a));
		for (int r = 0; r < 3; r++) {
			float rad = r == 0 ? 1.2 : (r == 1 ? 5.0 : 11.0);
			int kn = int(floor(level_t(TEXTURE, UV + o * rad * to_uv)));
			if (kn != k) {
				float w = r == 0 ? 1.0 : (r == 1 ? 0.55 : 0.25);
				near = max(near, w);
				if (r == 0) {
					seam = 1.0;
				}
			}
		}
	}
	float pedge = 0.0;
	vec2 cid = piece_cell(p, so, pedge);
	float ang = (h12(cid + vec2(float(k) * 13.0, 0.0) + so) - 0.5) * 3.14159 * 0.9 + 1.5708 * step(0.5, h12(vec2(float(k), 3.0) + so));
	vec2 gd = vec2(cos(ang), sin(ang));
	vec2 gn = vec2(-gd.y, gd.x);
	float gs = max(grain_scale, 0.05);
	float u = dot(p, gd) / gs;
	float v = dot(p, gn) / gs;
	float warp = fbm(vec2(u * 0.004, v * 0.02) + cid + so) * 6.0 + fbm(vec2(u * 0.02, v * 0.05) + so) * 0.8;
	float ring = fract(v * 0.055 + warp);
	float late = smoothstep(0.55, 0.85, ring) * (1.0 - smoothstep(0.92, 1.0, ring));
	float pores = smoothstep(0.62, 0.9, vnoise(vec2(u * 0.12, v * 1.6) + so)) * 0.5;
	float fleck = smoothstep(0.75, 0.95, vnoise(vec2(u * 0.05, v * 0.35) + cid * 2.0 + so));
	vec3 wood = species(k, n);
	float spec_id = h12(vec2(float(k), 7.0) + so);
	wood *= 0.92 + 0.12 * h12(cid + so + float(k));
	wood *= 1.0 - 0.22 * late - 0.18 * pores;
	wood *= 1.0 + 0.06 * fleck * step(0.5, spec_id);
	float lighter = float(k) / float(max(n - 1, 1));
	float sand = near * sand_shading * (0.4 + 0.6 * lighter);
	wood = mix(wood, wood * vec3(0.62, 0.46, 0.32), sand);
	float pseam = 1.0 - smoothstep(0.4, 1.4, pedge);
	seam = max(seam, pseam * 0.7);
	wood *= 1.0 - seam * 0.55;
	float la = radians(light_angle);
	vec2 ldir = vec2(cos(la), sin(la));
	float chat = 0.5 + 0.5 * cos(2.0 * (ang - la));
	wood *= 0.9 + 0.2 * chat;
	float sheen = fbm(p * 0.0015 + so) * smoothstep(-0.2, 1.0, dot(normalize(UV - 0.5 + 0.0001), -ldir));
	vec3 col = wood + vec3(1.0, 0.95, 0.85) * gloss * 0.16 * sheen;
	col = mix(col, col * vec3(1.03, 0.97, 0.88), gloss * 0.5);
	COLOR = vec4(clamp(col, 0.0, 1.0) * base.a, base.a);
}
