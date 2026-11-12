shader_type canvas_item;
render_mode blend_disabled;

uniform int enamels = 0;
uniform float wire : hint_range(0.5, 10.0) = 2.4;
uniform vec4 metal : source_color = vec4(0.86, 0.68, 0.32, 1.0);
uniform float gloss : hint_range(0.0, 1.0) = 0.7;
uniform float bubbles : hint_range(0.0, 1.0) = 0.4;
uniform float light_angle : hint_range(-180.0, 180.0) = -120.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform sampler2D effect_tex : filter_linear, repeat_disable;

const vec3 ENA[9] = vec3[](
	vec3(0.12, 0.62, 0.66), vec3(0.1, 0.22, 0.6), vec3(0.75, 0.13, 0.12), vec3(0.95, 0.75, 0.15),
	vec3(0.94, 0.92, 0.86), vec3(0.15, 0.5, 0.25), vec3(0.08, 0.08, 0.12), vec3(0.95, 0.5, 0.55),
	vec3(0.45, 0.78, 0.85)
);

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

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

vec3 enamel_of(sampler2D tex, vec2 uv) {
	vec4 s = texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
	vec3 c = s.rgb / max(s.a, 0.0001);
	if (enamels == 1) {
		vec3 best = ENA[0];
		float bd = 1e9;
		for (int i = 0; i < 9; i++) {
			vec3 d = c - ENA[i];
			float rm = 0.5 * (c.r + ENA[i].r);
			float e = (2.0 + rm) * d.r * d.r + 4.0 * d.g * d.g + (3.0 - rm) * d.b * d.b;
			if (e < bd) {
				bd = e;
				best = ENA[i];
			}
		}
		return best;
	}
	vec3 h = rgb2hsv(clamp(c, 0.0, 1.0));
	float grey = step(h.y * smoothstep(0.08, 0.3, h.z), 0.12);
	h.x = mix(floor(h.x * 12.0 + 0.5) / 12.0, 0.6, grey);
	h.y = mix(clamp(floor(h.y * 3.0 + 0.45) / 3.0 * 1.25 + 0.08, 0.0, 1.0), 0.06, grey);
	h.z = (floor(h.z * 4.0 + 0.5) + 0.3) / 4.6;
	return hsv2rgb(h);
}

void fragment() {
	vec4 base = texture(effect_tex, UV);
	vec2 out_size = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float ps = max(px_scale * out_size.x / max(tex_size.x, 1.0), 0.0001);
	vec2 p = UV * out_size / ps;
	vec2 to_uv = ps / out_size;
	vec2 so = vec2(float(seed) * 2.21, float(seed) * 3.97);
	vec3 e0 = enamel_of(TEXTURE, UV);
	float wd = 99.0;
	vec2 wdir = vec2(0.0);
	float near = 0.0;
	for (int i = 0; i < 12; i++) {
		float a = float(i) * 0.5236;
		vec2 o = vec2(cos(a), sin(a));
		for (int r = 1; r <= 4; r++) {
			float rad = float(r) * max(wire, 0.5) * 0.5;
			vec3 en = enamel_of(TEXTURE, UV + o * rad * to_uv);
			if (distance(en, e0) > 0.02) {
				if (rad < wd) {
					wd = rad;
					wdir = o;
				}
				break;
			}
		}
		for (int r2 = 0; r2 < 2; r2++) {
			float rr = r2 == 0 ? 6.0 : 12.0;
			vec3 en2 = enamel_of(TEXTURE, UV + o * rr * to_uv);
			if (distance(en2, e0) > 0.02) {
				near = max(near, r2 == 0 ? 1.0 : 0.5);
			}
		}
	}
	float W = max(wire, 0.5);
	float x = clamp(1.0 - wd / (W * 0.5 + 0.0001) * 0.5, 0.0, 1.0);
	float is_wire = 1.0 - smoothstep(W * 0.5 - 0.6, W * 0.5 + 0.6, wd);
	float la = radians(light_angle);
	vec3 L = normalize(vec3(cos(la), sin(la), 0.9));
	vec2 wv = vec2(vnoise(p * 0.012 + so), vnoise(p * 0.012 + so + 4.0)) - 0.5;
	vec2 wv2 = vec2(vnoise(p * 0.05 + so), vnoise(p * 0.05 + so + 8.0)) - 0.5;
	vec3 N = normalize(vec3(wv * 0.35 + wv2 * 0.08 + wdir * near * 0.12, 1.0));
	float meniscus = smoothstep(0.0, 1.0, near);
	float diff = clamp(dot(N, L), 0.0, 1.0);
	vec3 deep = e0 * e0 * 0.85;
	vec3 glow = mix(e0, vec3(1.0), 0.12);
	float centre = 1.0 - meniscus;
	vec3 en_col = mix(deep, glow, 0.45 + 0.4 * centre * vnoise(p * 0.02 + so) + 0.15 * diff);
	en_col *= 0.92 + 0.12 * vnoise(p * 0.15 + so);
	vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
	float spec = pow(clamp(dot(N, H), 0.0, 1.0), 90.0) * gloss * 1.6;
	float sheen = smoothstep(0.55, 0.95, dot(normalize(N.xy + 0.0001), -L.xy) * 0.5 + 0.5 + (vnoise(p * 0.004 + so) - 0.5) * 0.6) * gloss * 0.18;
	en_col += vec3(spec) + vec3(sheen);
	vec2 bg = p / 9.0;
	vec2 bi = floor(bg);
	float bub = 0.0;
	float bubh = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int xx = -1; xx <= 1; xx++) {
			vec2 o = bi + vec2(float(xx), float(y));
			if (h12(o + so * 3.0) > bubbles * 0.25) {
				continue;
			}
			vec2 c = o + h22(o + so);
			float r = (0.12 + 0.3 * h12(o + so + 1.0));
			float d = distance(bg, c) / r;
			if (d < 1.0) {
				bub = max(bub, smoothstep(0.65, 1.0, d));
				bubh = max(bubh, 1.0 - smoothstep(0.0, 0.3, distance(bg, c + vec2(-0.3, -0.3) * r) / r));
			}
		}
	}
	en_col = mix(en_col, deep * 0.6, bub * 0.7 * (1.0 - is_wire));
	en_col += vec3(bubh * 0.5) * (1.0 - is_wire);
	float xr = clamp(wd / (W * 0.5 + 0.0001), 0.0, 1.0);
	float wz = sqrt(max(1.0 - xr * xr, 0.0));
	vec3 Nw = normalize(vec3(-wdir * xr, wz + 0.001));
	float wdiff = clamp(dot(Nw, L), 0.0, 1.0);
	float wspec = pow(clamp(dot(Nw, H), 0.0, 1.0), 40.0);
	vec3 wc = metal.rgb * (0.35 + 0.75 * wdiff) + mix(metal.rgb, vec3(1.0), 0.6) * wspec * 0.9;
	wc *= 0.9 + 0.15 * vnoise(p * 0.4 + so);
	vec3 col = mix(en_col, wc, is_wire);
	COLOR = vec4(clamp(col, 0.0, 1.0) * base.a, base.a);
}
