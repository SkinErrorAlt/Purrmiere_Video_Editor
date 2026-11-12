shader_type canvas_item;
render_mode blend_disabled;

uniform int palette = 0;
uniform int baths : hint_range(2, 6) = 4;
uniform float contrast : hint_range(0.5, 2.5) = 1.15;
uniform float crackle : hint_range(0.0, 1.0) = 0.6;
uniform float crack_size : hint_range(6.0, 120.0) = 26.0;
uniform float wobble : hint_range(0.0, 1.0) = 0.5;
uniform float weave : hint_range(0.0, 1.0) = 0.5;
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
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return s;
}

vec3 dye(int i) {
	if (palette == 1) {
		return i == 0 ? vec3(0.78, 0.86, 0.95) : (i == 1 ? vec3(0.6, 0.72, 0.9) : (i == 2 ? vec3(0.52, 0.6, 0.82) : vec3(0.55, 0.58, 0.75)));
	}
	if (palette == 2) {
		return i == 0 ? vec3(1.0, 0.9, 0.45) : (i == 1 ? vec3(1.0, 0.68, 0.45) : (i == 2 ? vec3(0.85, 0.45, 0.45) : vec3(0.55, 0.42, 0.62)));
	}
	if (palette == 3) {
		return i == 0 ? vec3(0.95, 0.88, 0.62) : (i == 1 ? vec3(0.62, 0.85, 0.72) : (i == 2 ? vec3(0.5, 0.62, 0.72) : vec3(0.5, 0.45, 0.55)));
	}
	return i == 0 ? vec3(1.0, 0.88, 0.62) : (i == 1 ? vec3(0.82, 0.62, 0.44) : (i == 2 ? vec3(0.62, 0.6, 0.72) : vec3(0.5, 0.45, 0.5)));
}

vec3 level_colour(int k, vec3 cloth) {
	vec3 c = cloth;
	int n = clamp(baths, 2, 6);
	for (int i = 0; i < 6; i++) {
		if (i >= k) {
			break;
		}
		int di = int(floor(float(i) * 3.0 / float(max(n - 1, 1)) + 0.5));
		c *= dye(clamp(di, 0, 3));
	}
	return c;
}

float crack_net(vec2 p, vec2 so, out float seg) {
	vec2 g = floor(p);
	vec2 f = fract(p);
	float d1 = 9.0;
	float d2 = 9.0;
	vec2 c1 = vec2(0.0);
	vec2 c2 = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 r = o + h22(g + o + so) - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				c2 = c1;
				d1 = d;
				c1 = g + o;
			} else if (d < d2) {
				d2 = d;
				c2 = g + o;
			}
		}
	}
	seg = h12(c1 + c2 + so * 0.37);
	return sqrt(d2) - sqrt(d1);
}

void fragment() {
	vec4 base = texture(effect_tex, UV);
	vec2 out_size = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float ps = max(px_scale * out_size.x / max(tex_size.x, 1.0), 0.0001);
	vec2 p = UV * out_size / ps;
	vec2 so = vec2(float(seed) * 3.17, float(seed) * 5.31);
	vec2 wob = vec2(fbm(p * 0.012 + so), fbm(p * 0.012 + so + 31.0)) - 0.5;
	vec2 wob2 = vec2(vnoise(p * 0.09 + so), vnoise(p * 0.09 + so + 7.0)) - 0.5;
	vec2 suv = UV + (wob * 18.0 + wob2 * 3.0) * wobble * ps / out_size;
	vec4 sm = texture(TEXTURE, clamp(suv, vec2(0.0), vec2(1.0)));
	vec3 pc = sm.rgb / max(sm.a, 0.0001);
	float l = dot(pc, vec3(0.2126, 0.7152, 0.0722));
	l = clamp((l - 0.5) * contrast + 0.5, 0.0, 1.0);
	int n = clamp(baths, 2, 6);
	float t = (1.0 - l) * float(n) * 0.999;
	int k = int(floor(t));
	float fr = fract(t);
	vec3 cloth = vec3(0.96, 0.93, 0.86);
	vec3 col = level_colour(k, cloth);
	vec3 nxt = level_colour(min(k + 1, n), cloth);
	vec3 darkest = level_colour(n, cloth);
	if (palette == 4) {
		cloth = vec3(0.97, 0.95, 0.9);
		vec3 hue = pc / max(max(pc.r, max(pc.g, pc.b)), 0.001);
		hue = mix(vec3(1.0), hue, 0.85);
		float kk = float(k) / float(n);
		float kn = float(min(k + 1, n)) / float(n);
		col = cloth * mix(vec3(1.0), hue, smoothstep(0.0, 0.35, kk)) * (1.0 - 0.82 * kk * kk);
		nxt = cloth * mix(vec3(1.0), hue, smoothstep(0.0, 0.35, kn)) * (1.0 - 0.82 * kn * kn);
		darkest = cloth * hue * 0.16;
	}
	float rim = smoothstep(0.7, 1.0, fr + 0.15 * (vnoise(p * 0.2 + so) - 0.5)) * 0.4;
	col = mix(col, nxt, rim);
	float mott = fbm(p * 0.02 + so * 2.0);
	col *= 0.9 + 0.2 * mott;
	float seg = 0.0;
	vec2 cp = p / max(crack_size, 1.0) + (vec2(fbm(p * 0.05 + so), fbm(p * 0.05 + so + 3.0)) - 0.5) * 0.7;
	float e = crack_net(cp, so, seg);
	float wpx = 0.9 / max(crack_size, 1.0);
	float vein = 1.0 - smoothstep(wpx * 0.4, wpx * 2.2, e);
	float vis = smoothstep(0.25, 0.65, seg + 0.35 * (vnoise(p * 0.03 + so) - 0.5));
	float fv = fbm(p * 0.004 + so * 1.3 + wob * 0.6) - 0.5;
	float fine = 1.0 - smoothstep(0.0, fwidth(fv) * 1.1 + 0.00001, abs(fv));
	float halo = (1.0 - smoothstep(0.0, wpx * 7.0, e)) * vis * 0.22;
	vein = max(max(vein * vis, fine * 0.85), halo);
	float wet = 0.5 + 0.5 * vnoise(p * 0.15 + so);
	float waxed = 1.0 - float(k) / float(n);
	float vamt = clamp(crackle * 1.2, 0.0, 1.0) * vein * mix(0.35, 1.0, waxed) * (0.6 + 0.4 * wet);
	col = mix(col, darkest * 1.08, vamt);
	vec2 wq = p / 1.6;
	float wx = 0.5 + 0.5 * sin(wq.x * 3.14159);
	float wy = 0.5 + 0.5 * sin(wq.y * 3.14159);
	float over = step(0.5, fract((floor(wq.x) + floor(wq.y)) * 0.5));
	float wv = mix(wx, wy, over);
	float slub = vnoise(vec2(p.x * 0.02, floor(wq.y)) + so) * vnoise(vec2(floor(wq.x), p.y * 0.02) + so);
	col *= 1.0 - weave * (0.14 * (1.0 - wv) + 0.06 * slub);
	col = clamp(col, 0.0, 1.0);
	COLOR = vec4(col * base.a, base.a);
}
