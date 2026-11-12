shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_frame_physics/fp.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float strength = 1.3;
uniform int anchor = 0;
uniform float sheen = 0.4;

float height_of(vec2 uv) {
	if (anchor == 1) {
		return uv.y;
	}
	if (anchor == 2) {
		return abs(uv.y - 0.5) * 2.0;
	}
	return 1.0 - uv.y;
}

vec2 gel(vec2 uv, vec2 m1, vec2 m2, vec2 m3) {
	float h = height_of(uv);
	float up = anchor == 1 ? -1.0 : 1.0;
	float lean = h * h * (3.0 - h) * 0.5;
	float ripple = sin(3.14159 * h) * (1.0 - 1.6 * h);
	float dx = m1.x * lean * 1.2 + m2.x * ripple * 0.9;
	float squash = m3.y * h;
	if (anchor == 2) {
		squash = m3.y * (uv.y - 0.5) * 2.0 * h;
	}
	float bulge = (uv.x - 0.5) * m3.y * 1.6 * sin(3.14159 * clamp(h, 0.0, 1.0)) * up;
	float arc = (m1.x * m1.x) * 4.0 * lean * up;
	return vec2(dx + bulge, squash + arc);
}

void fragment() {
	vec2 m1 = fp_x(TEXTURE, 16) * strength;
	vec2 m2 = fp_x(TEXTURE, 17) * strength;
	vec2 m3 = fp_x(TEXTURE, 18) * strength;
	vec4 src = texture(effect_tex, UV);
	if (m1 == vec2(0.0) && m2 == vec2(0.0) && m3 == vec2(0.0)) {
		COLOR = src;
	} else {
		m1 = 0.06 * tanh(m1 / 0.06);
		m2 = 0.04 * tanh(m2 / 0.04);
		m3 = 0.05 * tanh(m3 / 0.05);
		vec2 d = gel(UV, m1, m2, m3);
		vec2 uv = fp_mirror(UV - d);
		vec3 col = texture(effect_tex, uv).rgb;
		float e = 0.01;
		vec2 dh = (gel(UV + vec2(0.0, e), m1, m2, m3) - gel(UV - vec2(0.0, e), m1, m2, m3)) / (2.0 * e);
		vec2 dw = (gel(UV + vec2(e, 0.0), m1, m2, m3) - gel(UV - vec2(e, 0.0), m1, m2, m3)) / (2.0 * e);
		vec3 n = normalize(vec3(dw.x * 3.0 + dh.x * 3.0, dh.y * 3.0 + dw.y * 3.0, 1.0));
		vec3 hv = normalize(vec3(-0.35, -0.55, 1.0));
		float spec = pow(max(dot(n, hv), 0.0), 60.0) - pow(hv.z, 60.0);
		float glow = clamp(spec, 0.0, 1.0);
		col += vec3(0.95, 0.98, 1.0) * glow * sheen * 1.4;
		col *= 1.0 - clamp(-(dw.x + dh.y), 0.0, 0.4) * sheen * 0.4;
		COLOR = vec4(clamp(col, 0.0, 1.0) * src.a, src.a);
	}
}
