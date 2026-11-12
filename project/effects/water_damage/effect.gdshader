shader_type canvas_item;
render_mode blend_disabled;

uniform float spread : hint_range(0.0, 1.0) = 0.6;
uniform float grow_time : hint_range(0.0, 30.0) = 0.0;
uniform int sources : hint_range(1, 8) = 3;
uniform float wash : hint_range(0.0, 1.0) = 0.6;
uniform float run : hint_range(0.0, 80.0) = 16.0;
uniform float tide : hint_range(0.0, 1.0) = 0.7;
uniform float rings : hint_range(0.0, 1.0) = 0.4;
uniform float cockle : hint_range(0.0, 1.0) = 0.5;
uniform float flaking : hint_range(0.0, 1.0) = 0.3;
uniform vec4 paper : source_color = vec4(0.95, 0.93, 0.87, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

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

float fbm(vec2 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	float n = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i >= oct) {
			break;
		}
		s += vnoise(p) * a;
		n += a;
		p = mat2(vec2(1.6, -1.2), vec2(1.2, 1.6)) * p + vec2(5.1, 1.7);
		a *= 0.5;
	}
	return s / max(n, 0.001);
}

vec3 unpm(vec4 c) {
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
}

float wet_field(vec2 q, float sp, vec2 so, int n) {
	vec2 wq = q + (vec2(fbm(q * 2.2 + so, 4), fbm(q * 2.2 + so + vec2(4.1, 7.3), 4)) - 0.5) * 0.32;
	float w = -9.0;
	for (int i = 0; i < 8; i++) {
		if (i >= n) {
			break;
		}
		float fi = float(i);
		vec2 h = vec2(hash12(so + fi * 7.13), hash12(so + fi * 3.71 + 9.0));
		float side = hash12(so + fi * 1.93 + 4.0);
		vec2 c = vec2(h.x * 1.9 - 0.1, h.y * 1.1 - 0.05);
		if (side < 0.3) {
			c.y = -0.08;
		} else if (side < 0.5) {
			c.y = 1.08;
		} else if (side < 0.62) {
			c.x = -0.1;
		} else if (side < 0.74) {
			c.x = 1.9;
		}
		float size = 0.5 + 0.5 * hash12(so + fi * 5.37 + 2.0);
		float start = hash12(so + fi * 2.17 + 8.0) * 0.35;
		float r = size * pow(clamp((sp - start) / (1.0 - start), 0.0, 1.0), 0.8) * 1.5;
		float d = length(wq - c);
		float wi = r - d;
		float k = 0.08;
		float hmix = clamp(0.5 + 0.5 * (wi - w) / k, 0.0, 1.0);
		w = mix(w, wi, hmix) + k * hmix * (1.0 - hmix);
	}
	w += (fbm(q * 14.0 + so * 1.3, 5) - 0.5) * 0.06;
	return w;
}

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 pix = UV * sz;
	float sk = mod(float(seed), 997.0);
	vec2 so = vec2(sk * 0.613 + 2.0, sk * 0.297 + 13.0);
	float sp = clamp(spread, 0.0, 1.0);
	if (grow_time > 0.0001) {
		sp *= clamp(max(clip_time, 0.0) / grow_time, 0.0, 1.0);
	}
	float aspect = sz.x / sz.y;
	vec2 q = vec2(UV.x * aspect, UV.y) * 1.0;
	int n = clamp(sources, 1, 8);
	float w = sp > 0.0005 ? wet_field(q, sp, so, n) : -9.0;
	vec4 base = texture(TEXTURE, UV);
	float a = base.a;
	vec3 rgb = unpm(base);
	vec2 grad = vec2(dFdx(w), dFdy(w));
	vec2 cp = pix / max(160.0 * ps, 1.0) + so;
	float big = fbm(cp, 3);
	float wr = 1.0 - abs(fbm(pix / max(14.0 * ps, 1.0) + so * 2.0, 4) * 2.0 - 1.0);
	wr = pow(wr, 6.0);
	float hgt = big * 0.7 + wr * 0.3 * smoothstep(0.0, 0.06, w);
	float lightv = (dFdx(hgt) * -1.0 + dFdy(hgt) * -1.0) * 60.0 / ps;
	if (sp <= 0.0005) {
		COLOR = base;
	} else {
		float px_h = 1.0 / sz.y;
		float inside = smoothstep(-0.002, 0.01, w);
		vec2 outward = -grad / max(length(grad), 1e-6);
		float carry = clamp(w / 0.12, 0.0, 1.0);
		float rp = run * ps * inside * (0.4 + 0.6 * carry);
		vec2 src = pix - outward * rp;
		vec3 ran = vec3(0.0);
		for (int i = 0; i < 6; i++) {
			float fi = float(i) / 5.0;
			vec2 tap = mix(pix, src, fi) + vec2(cos(fi * 9.0), sin(fi * 9.0)) * rp * 0.18;
			ran += unpm(texture(TEXTURE, clamp(tap / sz, vec2(0.0), vec2(1.0))));
		}
		ran /= 6.0;
		vec3 col = mix(rgb, ran, inside);
		float wo = wash * inside * (0.35 + 0.65 * smoothstep(0.0, 0.25, w));
		vec3 cmy = 1.0 - col;
		cmy *= vec3(1.0 - wo * 0.75, 1.0 - wo * 0.55, 1.0 - wo * 0.4);
		col = mix(1.0 - cmy, (1.0 - cmy) * paper.rgb, inside * 0.6);
		col = mix(col, col * vec3(1.0, 0.97, 0.9), inside * wash * 0.5);
		float front_px = w / px_h;
		float tl = front_px >= 0.0 ? exp(-front_px / (16.0 * ps)) * 0.75 + exp(-front_px / (2.5 * ps)) * 0.45 : exp(-pow(front_px / (1.6 * ps), 2.0));
		float feather = smoothstep(-0.01, 0.0, w) * (1.0 - inside) * (0.4 + 0.6 * fbm(pix / max(3.0 * ps, 1.0) + so, 3));
		vec3 brown = vec3(0.6, 0.42, 0.24);
		float tline = clamp(tl * tide + feather * tide * 0.3, 0.0, 1.0);
		col = mix(col, col * brown * 0.72, tline * 0.85);
		float ring_sum = 0.0;
		for (int k = 1; k <= 3; k++) {
			float lvl = float(k) * (0.05 + 0.025 * hash12(so + float(k)));
			float dd = (w - lvl) / px_h;
			float prof = dd >= 0.0 ? exp(-dd / (10.0 * ps)) : exp(-pow(dd / (1.5 * ps), 2.0));
			ring_sum += prof * (1.0 - float(k) * 0.2) * step(0.0, sp - 0.12 * float(k));
		}
		col = mix(col, col * brown, clamp(ring_sum * rings * 0.6, 0.0, 1.0));
		col = mix(col, col * vec3(0.97, 0.92, 0.84), inside * 0.35 * tide);
		float patchy = smoothstep(0.4, 0.75, fbm(pix / max(260.0 * ps, 1.0) + so * 0.7, 3));
		float sheen = clamp(lightv, -1.0, 1.0) * cockle * inside * (0.35 + 0.65 * patchy);
		col *= 1.0 + sheen * 0.08;
		col += vec3(0.3) * max(sheen, 0.0) * wr * patchy;
		float fl = fbm(pix / max(26.0 * ps, 1.0) + so * 3.0, 4) + (vnoise(pix / max(2.5 * ps, 1.0) + so) - 0.5) * 0.08;
		float near_front = smoothstep(0.0, 0.015, w) * (1.0 - smoothstep(0.05, 0.12, w));
		float lost = smoothstep(0.7, 0.72, fl + flaking * 0.16 * near_front - (1.0 - near_front) * 0.3) * step(0.001, flaking);
		col = mix(col, paper.rgb * (0.94 + 0.06 * big), lost);
		col = mix(col, col * 0.7, smoothstep(0.66, 0.7, fl + flaking * 0.16 * near_front - (1.0 - near_front) * 0.3) * (1.0 - lost) * step(0.001, flaking) * 0.6);
		COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
	}
}
