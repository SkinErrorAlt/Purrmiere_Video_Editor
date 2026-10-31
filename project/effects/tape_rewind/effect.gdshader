shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform int mode : hint_range(0, 4) = 0;
uniform float mess : hint_range(0.0, 1.0) = 0.7;
uniform float bands : hint_range(0.0, 1.0) = 0.6;
uniform float noise_lines : hint_range(0.0, 1.0) = 0.5;
uniform float bleed : hint_range(0.0, 1.0) = 0.5;
uniform float symbol_size : hint_range(0.3, 3.0) = 1.0;
uniform vec4 symbol_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
}

float tri_cov(vec2 p, vec2 tip, float len, float half_h, float dirx, float aa) {
	float x = (p.x - tip.x) * dirx;
	float yy = abs(p.y - tip.y);
	float slope = half_h / max(len, 0.0001);
	float d_edge = (yy - x * slope) / sqrt(1.0 + slope * slope);
	float d_back = x - len;
	float d_tip = -x;
	float d = max(d_edge, max(d_back, d_tip));
	return clamp(0.5 - d / aa, 0.0, 1.0);
}

float bar_cov(vec2 p, vec2 lo, vec2 hi, float aa) {
	vec2 c = (lo + hi) * 0.5;
	vec2 b = (hi - lo) * 0.5;
	vec2 q = abs(p - c) - b;
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
	return clamp(0.5 - d / aa, 0.0, 1.0);
}

float symbol(vec2 p, vec2 origin, float s, float aa) {
	float h = s * 0.62;
	float cy = origin.y + h;
	if (mode == 0) {
		return max(tri_cov(p, vec2(origin.x, cy), s, h, 1.0, aa), tri_cov(p, vec2(origin.x + s * 0.95, cy), s, h, 1.0, aa));
	}
	if (mode == 1) {
		return max(tri_cov(p, vec2(origin.x + s, cy), s, h, -1.0, aa), tri_cov(p, vec2(origin.x + s * 1.95, cy), s, h, -1.0, aa));
	}
	if (mode == 2) {
		return tri_cov(p, vec2(origin.x + s * 1.1, cy), s * 1.1, h, -1.0, aa);
	}
	if (mode == 3) {
		float bw = s * 0.36;
		float b1 = bar_cov(p, vec2(origin.x, cy - h), vec2(origin.x + bw, cy + h), aa);
		float b2 = bar_cov(p, vec2(origin.x + bw * 2.1, cy - h), vec2(origin.x + bw * 3.1, cy + h), aa);
		return max(b1, b2);
	}
	return 0.0;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float m = clamp(mess, 0.0, 1.0);
	float fr = floor(clip_time * 30.0);
	float dirv = mode == 0 ? -1.0 : (mode == 1 ? 1.0 : 0.25);
	vec2 uv = UV;
	uv.y += (hash12(vec2(fr, 3.1)) - 0.5) * 0.008 * m;
	uv.x += sin(UV.y * 55.0 + clip_time * 47.0) * 0.003 * m;
	float row = floor(UV.y * sz.y / (1.5 * ps));
	float in_band = 0.0;
	float bs = clamp(bands, 0.0, 1.0);
	for (int k = 0; k < 3; k++) {
		float fk = float(k);
		float bp = fract(fk / 3.0 + hash12(vec2(fk, 7.7)) * 0.2 + clip_time * (0.9 + 0.35 * fk) * dirv);
		float bw = 0.035 + 0.06 * hash12(vec2(fk, 1.3));
		float dy = fract(UV.y - bp + 0.5) - 0.5;
		float prof = smoothstep(-bw, bw * 0.4, dy) * (1.0 - smoothstep(bw * 0.4, bw, dy));
		float drag = prof * bs * m * (0.05 + 0.12 * hash12(vec2(row, fr + fk)));
		uv.x += drag * (dirv < 0.0 ? -1.0 : 1.0);
		in_band = max(in_band, prof);
	}
	float bl = clamp(bleed, 0.0, 1.0);
	float sh = (1.0 + 5.0 * bl) * ps / sz.x;
	vec2 cu = clamp(uv, vec2(0.0), vec2(1.0));
	vec4 bc = texture(TEXTURE, cu);
	vec3 base = straight(bc);
	vec3 soft = (straight(texture(TEXTURE, cu + vec2(sh, 0.0))) + straight(texture(TEXTURE, cu - vec2(sh, 0.0))) + base) / 3.0;
	float r = straight(texture(TEXTURE, cu + vec2(sh * 2.5, 0.0))).r;
	float b = straight(texture(TEXTURE, cu - vec2(sh * 2.0, 0.0))).b;
	vec3 rgb = mix(base, vec3(mix(soft.r, r, bl), soft.g, mix(soft.b, b, bl)), 0.5 + 0.5 * bl);
	float l = dot(rgb, LUMA);
	rgb = mix(vec3(l), rgb, 1.0 - 0.25 * m);
	rgb = (rgb - 0.5) * (1.0 + 0.15 * m) + 0.5 + 0.03 * m;
	float stat = hash12(floor(UV * sz / (2.0 * ps)) + fr * vec2(9.1, 4.7));
	rgb = mix(rgb, vec3(stat), in_band * bs * m * 0.45);
	float ns = clamp(noise_lines, 0.0, 1.0);
	float line_on = step(1.0 - (0.015 + 0.25 * in_band) * ns * (0.3 + 0.7 * m), hash12(vec2(row, fr * 1.7)));
	float streak = step(0.35, hash12(vec2(floor(UV.x * sz.x / (9.0 * ps)), row + fr)));
	rgb = mix(rgb, vec3(0.95), line_on * streak * 0.85);
	float a = bc.a;
	vec3 o = clamp(rgb, 0.0, 1.0);
	float s = 0.06 * sz.y * max(symbol_size, 0.05);
	vec2 origin = vec2(0.05 * sz.x, 0.07 * sz.y);
	vec2 pix = UV * sz;
	float aa = max(ps, 0.5);
	float sym = symbol(pix, origin, s, aa) * symbol_colour.a;
	float shadow = symbol(pix - vec2(2.0, 2.0) * ps, origin, s, aa * 2.0) * 0.55 * symbol_colour.a;
	vec4 outc = vec4(o * a, a);
	outc = vec4(0.0, 0.0, 0.0, shadow) + outc * (1.0 - shadow);
	outc = vec4(symbol_colour.rgb * sym, sym) + outc * (1.0 - sym);
	COLOR = outc;
}
