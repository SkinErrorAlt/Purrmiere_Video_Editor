#include "res://effects/pixel_motion_blur/flow.gdshaderinc"

vec2 motion_at(sampler2D f, vec2 uv) {
	return -flow_at(f, uv);
}

vec2 kit_global(sampler2D g, vec2 uv) {
	return -flow_at(g, uv);
}

float kit_luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float kit_hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 kit_hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 kit_hash32(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yzz) * p3.zyx);
}

vec2 motion_guided(sampler2D f, sampler2D pic, vec2 uv, float colour_k) {
	vec2 sz = vec2(textureSize(f, 0));
	vec2 p = uv * sz - 0.5;
	ivec2 i0 = ivec2(floor(p));
	vec2 fr = p - floor(p);
	vec3 c0 = texture(pic, uv).rgb;
	vec2 acc = vec2(0.0);
	float ws = 0.0;
	for (int dy = -1; dy <= 2; dy++) {
		for (int dx = -1; dx <= 2; dx++) {
			vec2 o = vec2(float(dx), float(dy)) - fr;
			float sw = max(0.0, 1.0 - abs(o.x) / 1.6) * max(0.0, 1.0 - abs(o.y) / 1.6);
			if (sw <= 0.0) {
				continue;
			}
			ivec2 q = i0 + ivec2(dx, dy);
			vec2 quv = (vec2(q) + 0.5) / sz;
			vec3 cq = texture(pic, quv).rgb;
			vec3 dc = c0 - cq;
			float cw = exp(-dot(dc, dc) * colour_k);
			float w = sw * cw + 1e-5 * sw;
			acc += flow_fetch(f, q) * w;
			ws += w;
		}
	}
	return -(acc / max(ws, 1e-6));
}

vec3 kit_oklab_to_srgb(vec3 lab) {
	float l_ = lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z;
	float m_ = lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z;
	float s_ = lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z;
	float l = l_ * l_ * l_;
	float m = m_ * m_ * m_;
	float s = s_ * s_ * s_;
	vec3 lin = vec3(
		4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
		-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
		-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s);
	lin = clamp(lin, 0.0, 1.0);
	return mix(lin * 12.92, 1.055 * pow(max(lin, vec3(1e-7)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), lin));
}

vec3 kit_srgb_to_oklab(vec3 c) {
	vec3 lin = mix(c / 12.92, pow(max((c + 0.055) / 1.055, vec3(1e-7)), vec3(2.4)), step(vec3(0.04045), c));
	float l = 0.4122214708 * lin.r + 0.5363325363 * lin.g + 0.0514459929 * lin.b;
	float m = 0.2119034982 * lin.r + 0.6806995451 * lin.g + 0.1073969566 * lin.b;
	float s = 0.0883024619 * lin.r + 0.2817188376 * lin.g + 0.6299787005 * lin.b;
	l = pow(max(l, 1e-9), 1.0 / 3.0);
	m = pow(max(m, 1e-9), 1.0 / 3.0);
	s = pow(max(s, 1e-9), 1.0 / 3.0);
	return vec3(
		0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s);
}

vec3 kit_heading_colour(float ang, float lightness, float chroma) {
	return kit_oklab_to_srgb(vec3(lightness, chroma * cos(ang), chroma * sin(ang)));
}
