shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 ink : source_color = vec4(0.12, 0.15, 0.35, 1.0);
uniform vec4 paper : source_color = vec4(0.97, 0.96, 0.93, 1.0);
uniform float size : hint_range(2.0, 30.0) = 6.0;
uniform float darkness : hint_range(0.0, 2.0) = 1.0;
uniform float wander : hint_range(0.0, 1.0) = 0.6;
uniform float outline : hint_range(0.0, 1.0) = 0.5;
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

float scrib(vec2 P, float a, float t) {
	vec2 q = rot(a) * P / size;
	float w = vn(q * 0.12 + a) * 6.28 * wander;
	float f = sin(q.x + 2.5 * sin(q.y * 0.35 + w)) * sin(q.y * 0.9 + 2.0 * cos(q.x * 0.3 - w));
	return smoothstep(0.35 * t, 0.0, abs(f)) * step(0.02, t);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float t = clamp(smoothstep(0.3, 0.92, 1.0 - lum(unp(c))) * darkness, 0.0, 1.0);
	vec2 P = PX(UV);
	float k = scrib(P, 0.3, clamp(t * 1.3, 0.0, 1.0));
	k = max(k, scrib(P, 1.9, clamp(t * 1.6 - 0.6, 0.0, 1.0)));
	k = max(k, scrib(P, 3.1, clamp(t * 2.0 - 1.2, 0.0, 1.0)));
	float e = edg(TEXTURE, UV, TX(1.2));
	k = max(k, smoothstep(0.25, 0.55, e) * outline);
	COLOR = pm(mix(paper.rgb, ink.rgb, clamp(k, 0.0, 1.0) * 0.9), c.a);
}
