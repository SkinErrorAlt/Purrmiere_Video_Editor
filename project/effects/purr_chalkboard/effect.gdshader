shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 board : source_color = vec4(0.12, 0.19, 0.16, 1.0);
uniform vec4 chalk : source_color = vec4(0.95, 0.95, 0.9, 1.0);
uniform int colour_mode : hint_range(0, 1) = 0;
uniform float line_width : hint_range(0.3, 5.0) = 1.5;
uniform float threshold : hint_range(0.0, 1.0) = 0.22;
uniform float shading : hint_range(0.0, 1.0) = 0.45;
uniform float dust : hint_range(0.0, 1.0) = 0.4;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

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

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 s = unp(c);
	vec2 P = PX(UV);
	float grit = vn(P * 0.9) * 0.6 + vn(P * 2.7) * 0.4;
	float e = edg(TEXTURE, UV, TX(line_width));
	float ln = smoothstep(threshold, threshold + 0.25, e) * smoothstep(0.25, 0.6, grit);
	vec2 q = rot(0.6) * P;
	float strokes = vn(q * vec2(0.03, 0.5));
	float sh = smoothstep(0.25, 1.0, lum(s)) * shading * smoothstep(0.35, 0.75, grit * 0.6 + strokes * 0.6);
	float haze = fbm(P * 0.004) * dust * 0.25 + fbm(rot(1.1) * P * vec2(0.002, 0.012)) * dust * 0.15;
	vec3 cc = colour_mode == 1 ? mix(vec3(lum(s)), s, 1.5) * 0.5 + 0.5 : chalk.rgb;
	vec3 o = board.rgb * (0.9 + 0.2 * vn(P * 0.05)) + vec3(haze);
	o = mix(o, clamp(cc, 0.0, 1.0), clamp(ln + sh, 0.0, 1.0));
	COLOR = pm(o, c.a);
}
