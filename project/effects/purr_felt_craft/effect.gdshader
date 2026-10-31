shader_type canvas_item;
render_mode blend_disabled;

uniform int levels : hint_range(2, 8) = 4;
uniform float fuzz : hint_range(0.0, 12.0) = 3.0;
uniform float fibre : hint_range(0.0, 1.0) = 0.5;
uniform float stitch : hint_range(0.0, 1.0) = 0.8;
uniform float stitch_len : hint_range(2.0, 30.0) = 7.0;
uniform vec4 thread : source_color = vec4(0.98, 0.95, 0.9, 1.0);
uniform float saturation : hint_range(0.0, 2.0) = 1.2;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }
float edg(sampler2D t, vec2 uv, vec2 d) { float tl = lum(texture(t, uv - d).rgb); float br = lum(texture(t, uv + d).rgb); float tr = lum(texture(t, uv + vec2(d.x, -d.y)).rgb); float bl = lum(texture(t, uv + vec2(-d.x, d.y)).rgb); float l = lum(texture(t, uv - vec2(d.x, 0.0)).rgb); float r = lum(texture(t, uv + vec2(d.x, 0.0)).rgb); float u = lum(texture(t, uv - vec2(0.0, d.y)).rgb); float b = lum(texture(t, uv + vec2(0.0, d.y)).rgb); float gx = tr + 2.0 * r + br - tl - 2.0 * l - bl; float gy = bl + 2.0 * b + br - tl - 2.0 * u - tr; return length(vec2(gx, gy)); }

void fragment() {
	vec2 P = PX(UV);
	vec2 j = (h22(floor(P * 1.3)) - 0.5) * 2.0 + (vec2(vn(P * 0.4), vn(P * 0.4 + 7.7)) - 0.5) * 2.0;
	vec4 c = texture(TEXTURE, UV + j * TX(fuzz));
	vec3 s = unp(c);
	float lv = float(levels);
	vec3 f = floor(s * lv + 0.5) / lv;
	f = clamp(mix(vec3(lum(f)), f, saturation), 0.0, 1.0);
	float tex = vn(rot(0.4) * P * vec2(0.6, 0.15)) * 0.5 + vn(rot(-0.9) * P * vec2(0.6, 0.15)) * 0.5;
	f *= 1.0 - fibre * 0.25 + fibre * 0.35 * tex;
	vec2 es = TX(6.0);
	float e = edg(TEXTURE, UV + es * 0.7, es);
	float dash = step(0.45, fract((P.x + P.y * 0.7) / stitch_len));
	float st = smoothstep(0.3, 0.5, e) * smoothstep(0.9, 0.5, e) * dash * stitch;
	f = mix(f, thread.rgb, st);
	COLOR = pm(f, c.a);
}
