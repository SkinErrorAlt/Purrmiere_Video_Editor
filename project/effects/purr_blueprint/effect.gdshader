shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 paper : source_color = vec4(0.05, 0.22, 0.48, 1.0);
uniform vec4 line_colour : source_color = vec4(0.88, 0.94, 1.0, 1.0);
uniform float threshold : hint_range(0.0, 1.0) = 0.22;
uniform float line_width : hint_range(0.3, 6.0) = 1.2;
uniform float grid : hint_range(4.0, 200.0) = 30.0;
uniform float grid_strength : hint_range(0.0, 1.0) = 0.3;
uniform float ghost : hint_range(0.0, 1.0) = 0.15;
uniform float texture_amount : hint_range(0.0, 1.0) = 0.4;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vn(p); p = p * 2.03 + vec2(17.1, 9.7); a *= 0.5; } return s / 0.97; }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }
float edg(sampler2D t, vec2 uv, vec2 d) { float tl = lum(texture(t, uv - d).rgb); float br = lum(texture(t, uv + d).rgb); float tr = lum(texture(t, uv + vec2(d.x, -d.y)).rgb); float bl = lum(texture(t, uv + vec2(-d.x, d.y)).rgb); float l = lum(texture(t, uv - vec2(d.x, 0.0)).rgb); float r = lum(texture(t, uv + vec2(d.x, 0.0)).rgb); float u = lum(texture(t, uv - vec2(0.0, d.y)).rgb); float b = lum(texture(t, uv + vec2(0.0, d.y)).rgb); float gx = tr + 2.0 * r + br - tl - 2.0 * l - bl; float gy = bl + 2.0 * b + br - tl - 2.0 * u - tr; return length(vec2(gx, gy)); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float e = edg(TEXTURE, UV, TX(line_width));
	float ln = smoothstep(threshold, threshold + 0.2, e);
	vec2 P = PX(UV);
	vec2 g = abs(fract(P / grid + 0.5) - 0.5) * grid;
	vec2 g5 = abs(fract(P / (grid * 5.0) + 0.5) - 0.5) * grid * 5.0;
	float gl = max(smoothstep(0.9, 0.2, min(g.x, g.y)) * 0.5, smoothstep(1.4, 0.4, min(g5.x, g5.y)));
	vec3 o = paper.rgb * (1.0 - texture_amount * 0.25 * (fbm(P * 0.01) - 0.5) * 2.0);
	o *= 1.0 - texture_amount * 0.08 * vn(P * 0.7);
	o = mix(o, line_colour.rgb, gl * grid_strength);
	o = mix(o, line_colour.rgb, (1.0 - lum(unp(c))) * ghost * 0.5);
	o = mix(o, line_colour.rgb, ln);
	COLOR = pm(o, c.a);
}
