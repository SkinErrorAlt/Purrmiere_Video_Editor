shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D near_tex : filter_linear, repeat_disable;
uniform sampler2D mid_tex : filter_linear, repeat_disable;
uniform sampler2D wide_tex : filter_linear, repeat_disable;
uniform sampler2D far_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float diffusion : hint_range(0.0, 1.0) = 0.7;
uniform float fibres : hint_range(0.0, 1.0) = 0.6;
uniform float clouds : hint_range(0.0, 1.0) = 0.5;
uniform float fibre_scale : hint_range(0.3, 3.0) = 1.0;
uniform float room_light : hint_range(0.0, 1.0) = 0.22;
uniform float backlight : hint_range(0.0, 3.0) = 1.0;
uniform float warmth : hint_range(0.0, 1.0) = 0.5;
uniform vec4 paper : source_color = vec4(0.95, 0.92, 0.85, 1.0);
uniform int seed : hint_range(0, 999) = 3;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vn(p); p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + 3.7; a *= 0.5; } return s / 0.96875; }
float fbm3(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 3; i++) { s += a * vn(p); p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + 3.7; a *= 0.5; } return s / 0.875; }

vec4 cubic(sampler2D tex, vec2 uv) {
	vec2 ts = vec2(textureSize(tex, 0));
	vec2 p = uv * ts - 0.5;
	vec2 f = fract(p);
	vec2 i = floor(p);
	vec2 f2 = f * f;
	vec2 f3 = f2 * f;
	vec2 w0 = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0;
	vec2 w1 = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
	vec2 w2 = (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0;
	vec2 w3 = f3 / 6.0;
	vec2 g0 = w0 + w1;
	vec2 g1 = w2 + w3;
	vec2 h0 = (i - 1.0 + w1 / g0 + 0.5) / ts;
	vec2 h1 = (i + 1.0 + w3 / g1 + 0.5) / ts;
	return g0.y * (g0.x * texture(tex, vec2(h0.x, h0.y)) + g1.x * texture(tex, vec2(h1.x, h0.y))) + g1.y * (g0.x * texture(tex, vec2(h0.x, h1.y)) + g1.x * texture(tex, vec2(h1.x, h1.y)));
}

float fibre_layer(vec2 P, float ang, float len, float wid, float sd) {
	float c = cos(ang);
	float s = sin(ang);
	vec2 r = vec2(c * P.x + s * P.y, -s * P.x + c * P.y);
	r.y += (fbm3(r / (len * 2.2) + sd * 0.3) - 0.5) * len * 1.1;
	r.x += (vn(r / (len * 1.5) + sd + 4.0) - 0.5) * len * 0.5;
	vec2 st = vec2(r.x / len, r.y / wid) + sd;
	float n = vn(st);
	float g = length(vec2(dFdx(n), dFdy(n))) + 0.0001;
	float thick = 0.8 + 1.6 * vn(st * vec2(0.6, 0.2) + 13.0);
	float line = 1.0 - smoothstep(0.2, 1.0, abs(n - 0.5) / g / thick);
	float seg = smoothstep(0.5, 0.64, vn(vec2(r.x / (len * 1.1), r.y / (wid * 2.0)) + sd * 1.7));
	return line * seg;
}

void fragment() {
	vec4 sharp = texture(effect_tex, UV);
	vec2 full = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float ps = max(px_scale * full.x / max(tex_size.x, 1.0), 0.0001);
	float sd = float(seed) * 7.31;
	vec2 P = UV * full / ps / max(fibre_scale, 0.05);
	float d = clamp(diffusion, 0.0, 1.0);
	vec4 near = cubic(near_tex, UV);
	vec4 mid = cubic(mid_tex, UV);
	vec4 far = cubic(far_tex, UV);
	vec4 wide = cubic(wide_tex, UV);
	float t = d * 3.0;
	vec3 L = t < 1.0 ? mix(near.rgb, mid.rgb, t) : (t < 2.0 ? mix(mid.rgb, wide.rgb, t - 1.0) : mix(wide.rgb, far.rgb, t - 2.0));
	L = L * 0.85 + far.rgb * 0.15;
	float form = fbm(P / 90.0 + sd) * 0.55 + fbm3(P / 26.0 + sd + 11.0) * 0.45;
	float fib = 0.0;
	fib += fibre_layer(P, -0.18 + 0.1 * sin(sd), 130.0, 10.0, sd) * 0.6;
	fib += fibre_layer(P, 0.35, 110.0, 9.0, sd + 3.3) * 0.6;
	fib += fibre_layer(P, 1.4 + 0.2 * cos(sd), 90.0, 9.0, sd + 6.1) * 0.4;
	fib += fibre_layer(P, -0.8, 160.0, 12.0, sd + 9.4) * 0.5;
	fib = min(fib, 1.2);
	vec2 cid = floor(P / 140.0);
	vec2 cf = P - (cid + 0.25 + 0.5 * vec2(h12(cid + sd + 1.0), h12(cid + sd + 2.0))) * 140.0;
	float ca = h12(cid + sd + 3.0) * 6.2832;
	vec2 cr = vec2(cos(ca) * cf.x + sin(ca) * cf.y, -sin(ca) * cf.x + cos(ca) * cf.y) / vec2(5.0 + 7.0 * h12(cid + sd + 4.0), 1.6 + 1.2 * h12(cid + sd + 5.0));
	float chiri = smoothstep(1.0, 0.6, length(cr) + 0.6 * (vn(cf * 0.5 + sd) - 0.5)) * step(0.72, h12(cid + sd)) * fibres;
	float thick = 0.5 + clouds * (form - 0.5) * 2.0 + fibres * fib * 0.6;
	vec3 warm = mix(vec3(1.0), vec3(1.0, 0.88, 0.68), warmth);
	vec3 trans = L * backlight * warm * paper.rgb * clamp(1.2 - 0.62 * thick, 0.05, 1.5);
	vec3 refl = paper.rgb * room_light * (0.68 + 0.5 * thick);
	vec3 o = trans + refl;
	o = mix(o, o * vec3(0.45, 0.38, 0.3), chiri * 0.8);
	COLOR = vec4(clamp(o, 0.0, 1.0) * sharp.a, sharp.a);
}
