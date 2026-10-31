shader_type canvas_item;
render_mode blend_disabled;

uniform float pressure : hint_range(0.0, 2.0) = 1.0;
uniform float angle : hint_range(-90.0, 90.0) = 55.0;
uniform float stroke : hint_range(1.0, 12.0) = 2.5;
uniform float tooth : hint_range(0.0, 1.0) = 0.6;
uniform float colour_boost : hint_range(0.0, 2.0) = 1.35;
uniform float outline : hint_range(0.0, 1.0) = 0.6;
uniform vec4 paper : source_color = vec4(0.98, 0.97, 0.94, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }
float edg(sampler2D t, vec2 uv, vec2 d) { float tl = lum(texture(t, uv - d).rgb); float br = lum(texture(t, uv + d).rgb); float tr = lum(texture(t, uv + vec2(d.x, -d.y)).rgb); float bl = lum(texture(t, uv + vec2(-d.x, d.y)).rgb); float l = lum(texture(t, uv - vec2(d.x, 0.0)).rgb); float r = lum(texture(t, uv + vec2(d.x, 0.0)).rgb); float u = lum(texture(t, uv - vec2(0.0, d.y)).rgb); float b = lum(texture(t, uv + vec2(0.0, d.y)).rgb); float gx = tr + 2.0 * r + br - tl - 2.0 * l - bl; float gy = bl + 2.0 * b + br - tl - 2.0 * u - tr; return length(vec2(gx, gy)); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 s = unp(c);
	vec3 wax = clamp(mix(vec3(lum(s)), s, colour_boost) * 0.95, 0.0, 1.0);
	vec2 P = PX(UV);
	vec2 q = rot(radians(angle)) * P;
	float st = vn(q * vec2(0.04, 1.0 / stroke)) * 0.6 + vn(q * vec2(0.015, 0.4 / stroke)) * 0.4;
	float tth = vn(P * 0.8) * 0.5 + vn(P * 2.1) * 0.5;
	float pr = clamp((1.0 - lum(s) * 0.75) * pressure, 0.0, 1.0);
	float cov = smoothstep(1.0 - pr - 0.08, 1.0 - pr + 0.08, mix(st, tth, tooth * 0.7));
	float e = edg(TEXTURE, UV, TX(1.5));
	float ln = smoothstep(0.25, 0.6, e) * outline * (0.6 + 0.4 * tth);
	vec3 o = mix(paper.rgb, wax, max(cov, ln * 0.8));
	o = mix(o, wax * 0.55, ln * 0.6);
	COLOR = pm(o, c.a);
}
