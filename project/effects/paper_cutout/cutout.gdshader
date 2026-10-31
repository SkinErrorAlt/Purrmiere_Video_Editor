shader_type canvas_item;
render_mode blend_disabled;

uniform int levels : hint_range(2, 12) = 5;
uniform float shadow : hint_range(0.0, 1.0) = 0.5;
uniform float shadow_distance : hint_range(0.0, 30.0) = 5.0;
uniform float shadow_angle : hint_range(-180.0, 180.0) = -45.0;
uniform int stack : hint_range(0, 1) = 0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float paper_texture : hint_range(0.0, 1.0) = 0.3;
uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

#define TAP(p) texture(TEXTURE, clamp(p, vec2(0.0), vec2(1.0)))

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 srgb_to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	vec3 lo = c / 12.92;
	vec3 hi = pow((c + 0.055) / 1.055, vec3(2.4));
	return mix(lo, hi, step(vec3(0.04045), c));
}

vec3 linear_to_srgb(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	vec3 lo = c * 12.92;
	vec3 hi = 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055;
	return mix(lo, hi, step(vec3(0.0031308), c));
}

vec3 to_oklab(vec3 srgb) {
	vec3 c = srgb_to_linear(srgb);
	float l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b;
	float m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b;
	float s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b;
	l = pow(max(l, 0.0), 1.0 / 3.0);
	m = pow(max(m, 0.0), 1.0 / 3.0);
	s = pow(max(s, 0.0), 1.0 / 3.0);
	return vec3(
		0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s);
}

vec3 from_oklab(vec3 lab) {
	float l = lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z;
	float m = lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z;
	float s = lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z;
	l = l * l * l;
	m = m * m * m;
	s = s * s * s;
	vec3 lin = vec3(
		4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
		-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
		-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s);
	return linear_to_srgb(lin);
}

float lightness_of(vec4 s) {
	vec3 c = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
	return to_oklab(c).x;
}

float layer_of(float l, float n, float w) {
	float v = clamp(l, 0.0, 1.0) * n;
	float q = floor(v) + smoothstep(0.5 - w, 0.5 + w, fract(v));
	return stack == 1 ? n - q : q;
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float n = float(max(levels, 2) - 1);
	vec4 c = texture(TEXTURE, UV);
	float a = texture(effect_tex, UV).a;
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec3 lab = to_oklab(rgb);
	float v = clamp(lab.x, 0.0, 1.0) * n;
	float w = clamp(fwidth(v), 0.001, 0.5);
	float q = floor(v) + smoothstep(0.5 - w, 0.5 + w, fract(v));
	float h = stack == 1 ? n - q : q;
	float ra = radians(shadow_angle);
	vec2 dir = vec2(cos(ra), -sin(ra));
	float dist_px = shadow_distance * px_scale;
	float shade = 0.0;
	if (shadow > 0.0 && dist_px > 0.5) {
		for (int k = 1; k <= 6; k++) {
			float fk = float(k);
			vec2 off = dir * dist_px * fk / 6.0 / dims;
			float hq = layer_of(lightness_of(TAP(UV - off)), n, w);
			float weight = 1.0 - (fk - 1.0) / 6.0;
			shade = max(shade, clamp(hq - h, 0.0, 1.0) * weight);
		}
	}
	float rim = 0.0;
	if (shadow > 0.0) {
		vec2 off = dir * max(1.5 * px_scale, 1.0) / dims;
		rim = clamp(h - layer_of(lightness_of(TAP(UV - off)), n, w), 0.0, 1.0);
	}
	lab.x = mix(0.15, 0.97, q / n);
	lab.yz *= saturation;
	rgb = from_oklab(lab);
	rgb *= 1.0 - shadow * shade * 0.6;
	rgb = mix(rgb, vec3(1.0), rim * shadow * 0.25);
	vec2 pp = UV * dims / max(px_scale, 0.0001);
	float fibre = value_noise(pp / 3.0 + q * 17.31) * 0.6 + value_noise(pp / 11.0 + q * 5.17) * 0.4;
	rgb *= 1.0 + (fibre - 0.5) * paper_texture * 0.25;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
