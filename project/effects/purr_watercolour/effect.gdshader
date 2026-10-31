shader_type canvas_item;
render_mode blend_disabled;

uniform float bleed : hint_range(0.0, 40.0) = 9.0;
uniform int levels : hint_range(3, 16) = 7;
uniform float edge_dark : hint_range(0.0, 1.0) = 0.6;
uniform float granulation : hint_range(0.0, 1.0) = 0.5;
uniform float paper_tex : hint_range(0.0, 1.0) = 0.5;
uniform vec4 paper : source_color = vec4(0.98, 0.96, 0.92, 1.0);
uniform float wet : hint_range(0.0, 2.0) = 0.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

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
	vec2 P = PX(UV);
	float tt = clip_time * wet * 0.3;
	vec2 w = vec2(fbm(P * 0.02 + tt), fbm(P * 0.02 + vec2(31.7, 5.3) - tt)) - 0.5;
	vec2 uv2 = UV + w * TX(bleed) * 2.5;
	vec4 acc = vec4(0.0);
	for (int i = 0; i < 6; i++) {
		float a = float(i) * 1.0472;
		acc += texture(TEXTURE, uv2 + vec2(cos(a), sin(a)) * TX(bleed * 0.4));
	}
	acc = acc / 6.0 * 0.6 + texture(TEXTURE, uv2) * 0.4;
	vec3 s = unp(acc);
	float lv = float(levels);
	vec3 q = floor(s * lv + vn(P * 0.03) * 0.8) / lv;
	s = mix(s, q, 0.6);
	float e = edg(TEXTURE, uv2, TX(2.0));
	s *= 1.0 - clamp(e, 0.0, 1.0) * edge_dark * 0.5;
	s *= 1.0 - granulation * 0.3 * (fbm(P * 0.18) - 0.5) * (1.0 - lum(s));
	vec3 o = paper.rgb * mix(vec3(1.0), s, 0.95);
	o *= 1.0 - paper_tex * 0.12 * (vn(P * 0.45) + vn(P * 1.3) - 1.0);
	COLOR = pm(o, clamp(acc.a * 1.15, 0.0, 1.0));
}
