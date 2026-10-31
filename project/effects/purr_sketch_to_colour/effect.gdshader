shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int timing : hint_range(0, 2) = 0;
uniform float auto_len : hint_range(0.05, 10.0) = 1.0;
uniform vec4 paper : source_color = vec4(0.97, 0.96, 0.92, 1.0);
uniform vec4 graphite : source_color = vec4(0.2, 0.2, 0.24, 1.0);
uniform float line_width : hint_range(0.3, 5.0) = 1.2;
uniform float threshold : hint_range(0.0, 1.0) = 0.2;
uniform float hatching : hint_range(0.0, 1.0) = 0.4;
uniform float patch : hint_range(20.0, 1000.0) = 260.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;
uniform float clip_duration = 10.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vn(p); p = p * 2.03 + vec2(17.1, 9.7); a *= 0.5; } return s / 0.97; }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }
float edg(sampler2D t, vec2 uv, vec2 d) { float tl = lum(texture(t, uv - d).rgb); float br = lum(texture(t, uv + d).rgb); float tr = lum(texture(t, uv + vec2(d.x, -d.y)).rgb); float bl = lum(texture(t, uv + vec2(-d.x, d.y)).rgb); float l = lum(texture(t, uv - vec2(d.x, 0.0)).rgb); float r = lum(texture(t, uv + vec2(d.x, 0.0)).rgb); float u = lum(texture(t, uv - vec2(0.0, d.y)).rgb); float b = lum(texture(t, uv + vec2(0.0, d.y)).rgb); float gx = tr + 2.0 * r + br - tl - 2.0 * l - bl; float gy = bl + 2.0 * b + br - tl - 2.0 * u - tr; return length(vec2(gx, gy)); }
float PG() { if (timing == 1) { return 1.0 - clamp(clip_time / max(auto_len, 0.01), 0.0, 1.0); } if (timing == 2) { return clamp((clip_time - clip_duration + auto_len) / max(auto_len, 0.01), 0.0, 1.0); } return progress; }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float pg = PG();
	vec3 s = unp(c);
	vec2 P = PX(UV);
	float e = edg(TEXTURE, UV, TX(line_width));
	float ln = smoothstep(threshold, threshold + 0.25, e) * (0.7 + 0.3 * vn(P * 0.25));
	vec2 q = rot(0.7) * P;
	float ht = smoothstep(0.55, 0.45, abs(fract(q.y / 5.0) - 0.5) * 2.0 + lum(s) * 0.9 - 0.25) * hatching;
	float ink = clamp(max(ln, ht * 0.6), 0.0, 1.0);
	float nz = fbm(P / patch);
	float cfill = smoothstep(pg * 2.2 - 0.15, pg * 2.2 + 0.05, nz + 0.1);
	float erase = smoothstep((pg - 0.5) * 2.2 - 0.15, (pg - 0.5) * 2.2 + 0.05, nz + 0.1);
	vec3 sketch = mix(paper.rgb, graphite.rgb, ink * erase);
	vec3 o = mix(sketch, s, cfill);
	float fade = 1.0 - smoothstep(0.9, 1.0, pg);
	COLOR = pg <= 0.0 ? c : pm(o, mix(1.0, c.a, cfill)) * fade;
}
