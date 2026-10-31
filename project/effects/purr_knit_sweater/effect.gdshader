shader_type canvas_item;
render_mode blend_disabled;

uniform float stitch : hint_range(4.0, 60.0) = 12.0;
uniform int levels : hint_range(2, 12) = 7;
uniform float fuzz : hint_range(0.0, 1.0) = 0.5;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

float leg(vec2 p, float s) {
	vec2 q = rot(s * 0.5) * p;
	return length(q / vec2(0.25, 0.5));
}

void fragment() {
	vec2 P = PX(UV) / vec2(stitch, stitch * 0.85);
	vec2 cl = floor(P);
	vec2 f = fract(P);
	vec2 cuv = (cl + 0.5) * vec2(stitch, stitch * 0.85) * px_scale / max(tex_size, vec2(1.0));
	vec4 c = texture(TEXTURE, cuv);
	vec3 s = unp(c);
	float lv = float(levels);
	vec3 y = floor(s * lv + 0.5) / lv;
	float a = leg(f - vec2(0.28, 0.55), 1.0);
	float b = leg(f - vec2(0.72, 0.55), -1.0);
	float d = min(a, b);
	float loop = smoothstep(1.05, 0.9, d);
	float sh = 1.0 - shading * 0.5 * d * d;
	vec2 fp = PX(UV);
	float fib = vn(rot(a < b ? 0.5 : -0.5) * fp * vec2(0.25, 1.4));
	vec3 o = y * sh * (1.0 - fuzz * 0.25 + fuzz * 0.4 * fib);
	o = mix(y * 0.35, o, loop);
	COLOR = pm(o, step(0.5, c.a));
}
