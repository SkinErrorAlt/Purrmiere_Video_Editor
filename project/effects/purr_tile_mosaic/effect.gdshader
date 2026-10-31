shader_type canvas_item;
render_mode blend_disabled;

uniform float tile : hint_range(4.0, 60.0) = 14.0;
uniform float grout : hint_range(0.0, 0.4) = 0.12;
uniform vec4 grout_colour : source_color = vec4(0.86, 0.82, 0.74, 1.0);
uniform float jitter : hint_range(0.0, 1.0) = 0.5;
uniform int levels : hint_range(3, 24) = 10;
uniform float polish : hint_range(0.0, 1.0) = 0.4;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

void fragment() {
	vec2 P = PX(UV) / tile;
	float row = floor(P.y);
	P.x += h12(vec2(row, 7.0)) * 0.9;
	vec2 cl = floor(P);
	vec2 hh = h22(cl);
	vec2 f = fract(P) - 0.5;
	vec2 q = rot((hh.x - 0.5) * 0.35 * jitter) * (f - (hh - 0.5) * 0.08 * jitter);
	vec2 back = (cl + 0.5 + vec2(-h12(vec2(row, 7.0)) * 0.9, 0.0)) * tile * px_scale / max(tex_size, vec2(1.0));
	vec4 c = texture(TEXTURE, back);
	vec3 s = unp(c);
	float lv = float(levels);
	s = floor(s * lv + 0.5) / lv;
	float e = max(abs(q.x), abs(q.y));
	float lim = 0.5 - grout * 0.5 - jitter * 0.03;
	float t = smoothstep(lim + 0.02, lim - 0.02, e);
	s *= 1.0 + polish * 0.25 * (0.5 - length(q + vec2(0.15, 0.15))) + (hh.y - 0.5) * 0.08;
	vec3 o = mix(grout_colour.rgb * (0.9 + 0.1 * vn(PX(UV) * 0.7)), s, t);
	COLOR = pm(o, texture(TEXTURE, UV).a);
}
