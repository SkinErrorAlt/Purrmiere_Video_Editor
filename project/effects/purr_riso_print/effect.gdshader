shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 ink_a : source_color = vec4(1.0, 0.28, 0.55, 1.0);
uniform vec4 ink_b : source_color = vec4(0.0, 0.45, 0.75, 1.0);
uniform vec4 paper : source_color = vec4(0.97, 0.95, 0.9, 1.0);
uniform float split : hint_range(-2.0, 2.0) = 1.0;
uniform float dot_size : hint_range(2.0, 30.0) = 5.0;
uniform float offset : hint_range(0.0, 20.0) = 3.0;
uniform float offset_angle : hint_range(-180.0, 180.0) = 30.0;
uniform float grain : hint_range(0.0, 1.0) = 0.4;
uniform float wobble : hint_range(0.0, 1.0) = 0.2;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }

float dots(vec2 p, float cov, float ang) {
	vec2 q = rot(ang) * p / dot_size;
	float d = length(fract(q) - 0.5);
	float r = sqrt(clamp(cov, 0.0, 1.0)) * 0.72;
	float aa = 0.7 / dot_size;
	return smoothstep(r + aa, r - aa, d);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float fr = floor(clip_time * 12.0);
	vec2 wob = (h22(vec2(fr, 3.1)) - 0.5) * wobble * 2.0;
	float an = radians(offset_angle);
	vec2 off = TX(offset) * vec2(cos(an), sin(an));
	vec3 sa = unp(texture(TEXTURE, UV + off + wob * TX(1.5)));
	vec3 sb = unp(texture(TEXTURE, UV - off - wob * TX(1.5)));
	float ca = clamp(1.0 - lum(sa) * 1.1 + (sa.r - sa.b) * split, 0.0, 1.0);
	float cb = clamp(1.0 - lum(sb) * 1.5 - (sb.r - sb.b) * split, 0.0, 1.0);
	vec2 P = PX(UV);
	float n = 1.0 - grain * 0.5 + grain * vn(P * 0.6) * 0.8 + grain * 0.2 * vn(P * 0.05);
	float da = dots(P, ca * n, 0.26);
	float db = dots(P, cb * n, 1.31);
	vec3 o = paper.rgb * mix(vec3(1.0), ink_a.rgb, da * ink_a.a) * mix(vec3(1.0), ink_b.rgb, db * ink_b.a);
	COLOR = pm(o, c.a);
}
