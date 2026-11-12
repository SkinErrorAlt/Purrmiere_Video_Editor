shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform int inks : hint_range(0, 1) = 0;
uniform float lpi : hint_range(45.0, 133.0) = 65.0;
uniform float width_in : hint_range(1.5, 12.0) = 3.5;
uniform float gain : hint_range(0.0, 1.0) = 0.5;
uniform float density : hint_range(0.3, 1.0) = 0.85;
uniform float yellowing : hint_range(0.0, 1.0) = 0.45;
uniform float show : hint_range(0.0, 1.0) = 0.35;
uniform float misregister : hint_range(0.0, 8.0) = 1.5;
uniform int seed : hint_range(0, 999) = 7;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(1.0);
}

float spot(vec2 px, float cell, float ang) {
	float c = cos(ang);
	float s = sin(ang);
	vec2 g = vec2(c * px.x + s * px.y, -s * px.x + c * px.y) / cell;
	vec2 f = fract(g) - 0.5;
	return 0.5 - 0.25 * (cos(6.2831853 * f.x) + cos(6.2831853 * f.y));
}

float spread(float k) {
	return clamp(k + gain * 0.95 * k * (1.0 - k) + gain * 0.06 * smoothstep(0.6, 1.0, k), 0.0, 1.0);
}

float screen_ink(float k, vec2 px, float cell, float ang, float rag, float aa) {
	float drop = smoothstep(0.03, 0.07, k);
	float kk = spread(k) * drop;
	float sp = spot(px, cell, ang);
	float soft = aa + 0.03 + gain * 0.05;
	float core = smoothstep(-soft, soft, kk + rag * drop - sp);
	float wick = smoothstep(-soft - 0.06 - gain * 0.12, soft, kk + rag * 1.6 * drop - sp) * drop;
	return max(core, wick * (0.18 + gain * 0.2));
}

void fragment() {
	vec4 src = texture(effect_tex, UV);
	float alpha = src.a;
	vec2 out_size = vec2(textureSize(effect_tex, 0));
	vec2 px = UV * out_size;
	float ps = max(px_scale * 4.0, 0.0001);
	vec2 P = px / ps;
	vec2 off = vec2(float(seed) * 13.7, float(seed) * 7.3);
	float cell = max(out_size.x / max(lpi * width_in, 1.0), 1.5);
	float aa = clamp(0.35 / cell, 0.02, 0.35);
	float fib = vn(vec2(P.x * 0.9 + P.y * 0.25, P.y * 0.35) + off) * 0.5 + vn(vec2(P.x * 0.3 - P.y * 0.2, P.x * 0.15 + P.y * 0.9) + off * 1.3) * 0.5;
	float rag = (fib - 0.5) * (0.08 + gain * 0.14);
	float mottle = vn(P * 0.015 + off) * 0.6 + vn(P * 0.06 + off * 2.0) * 0.4;
	float dmax = density * mix(0.9, 1.0, mottle);
	vec3 paper_new = vec3(0.89, 0.875, 0.83);
	vec3 paper_old = vec3(0.86, 0.77, 0.58);
	vec2 e = min(UV, 1.0 - UV);
	float edge_age = 1.0 - smoothstep(0.0, 0.18, min(e.x, e.y * 1.6));
	float blotch = vn(P * 0.004 + off) * 0.7 + vn(P * 0.012 + off * 0.5) * 0.3;
	float age = clamp(yellowing * (0.75 + 0.5 * blotch + 0.35 * edge_age), 0.0, 1.0);
	vec3 paper = mix(paper_new, paper_old, age);
	paper *= 0.97 + 0.06 * (fib - 0.5) * 2.0;
	float fleck = smoothstep(0.985, 1.0, vn(P * 0.5 + off * 4.0)) * step(0.6, h12(floor(P * 0.13) + off));
	paper *= 1.0 - fleck * 0.45;
	float ghost = texture(TEXTURE, UV).r;
	paper *= 1.0 - show * 0.42 * ghost;
	vec3 col = paper;
	if (inks == 0) {
		vec3 rgb = straight(src);
		float l = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
		float k = pow(clamp((1.0 - l) * 0.98 + 0.01, 0.0, 1.0), 1.0 + gain * 0.3);
		float cover = screen_ink(k, px, cell, radians(45.0), rag, aa);
		col *= mix(vec3(1.0), vec3(0.11, 0.11, 0.12), cover * dmax);
	} else {
		float s = float(seed);
		float mr = misregister * ps;
		vec2 dc = vec2(cos(s * 1.7), sin(s * 1.7)) * mr / out_size;
		vec2 dm = vec2(cos(s * 2.9 + 2.0), sin(s * 2.9 + 2.0)) * mr / out_size;
		vec2 dy = vec2(cos(s * 4.1 + 4.0), sin(s * 4.1 + 4.0)) * mr / out_size;
		vec3 rc = straight(texture(effect_tex, UV - dc));
		vec3 rm = straight(texture(effect_tex, UV - dm));
		vec3 ry = straight(texture(effect_tex, UV - dy));
		vec3 rk = straight(src);
		float kk = min(1.0 - rk.r, min(1.0 - rk.g, 1.0 - rk.b));
		float kc = kk * 0.7;
		float c_i = clamp((1.0 - rc.r - kc) / max(1.0 - kc, 0.001), 0.0, 1.0);
		float m_i = clamp((1.0 - rm.g - kc) / max(1.0 - kc, 0.001), 0.0, 1.0);
		float y_i = clamp((1.0 - ry.b - kc) / max(1.0 - kc, 0.001), 0.0, 1.0);
		float k_i = clamp((kk - 0.3) / 0.7, 0.0, 1.0) * 0.95;
		float cc = screen_ink(c_i, px - dc * out_size, cell, radians(15.0), rag, aa);
		float cm = screen_ink(m_i, px - dm * out_size, cell, radians(75.0), rag, aa);
		float cy = screen_ink(y_i, px - dy * out_size, cell, radians(0.0), rag, aa);
		float ck = screen_ink(k_i, px, cell, radians(45.0), rag, aa);
		col *= mix(vec3(1.0), vec3(0.3, 0.66, 0.86), cc * dmax);
		col *= mix(vec3(1.0), vec3(0.9, 0.36, 0.58), cm * dmax);
		col *= mix(vec3(1.0), vec3(0.98, 0.88, 0.3), cy * dmax);
		col *= mix(vec3(1.0), vec3(0.16, 0.16, 0.17), ck * dmax);
	}
	COLOR = vec4(clamp(col, 0.0, 1.0) * alpha, alpha);
}
