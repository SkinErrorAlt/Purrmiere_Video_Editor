shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 ink : source_color = vec4(0.08, 0.08, 0.1, 1.0);
uniform vec4 paper : source_color = vec4(0.95, 0.93, 0.86, 1.0);
uniform int levels : hint_range(2, 6) = 3;
uniform float bleed : hint_range(0.0, 30.0) = 5.0;
uniform float dry : hint_range(0.0, 1.0) = 0.45;
uniform float edge_ink : hint_range(0.0, 1.0) = 0.7;
uniform bool seal = true;
uniform vec4 seal_colour : source_color = vec4(0.78, 0.14, 0.1, 1.0);
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
	vec2 P = PX(UV);
	vec2 j = vec2(fbm(P * 0.03), fbm(P * 0.03 + 9.1)) - 0.5;
	vec4 s4 = texture(TEXTURE, UV + j * TX(bleed) * 2.0);
	float t = 1.0 - lum(unp(s4));
	float lv = float(levels);
	float q = floor(t * lv + 0.35) / lv;
	q = mix(q, t, 0.25);
	float streak = vn(P * vec2(0.012, 0.35));
	q *= 1.0 - dry * smoothstep(0.35, 0.9, streak) * smoothstep(0.15, 0.6, q) * 0.7;
	q *= 0.85 + 0.3 * fbm(P * 0.08);
	float e = edg(TEXTURE, UV + j * TX(bleed), TX(1.5));
	float ln = smoothstep(0.25, 0.6, e) * edge_ink * (0.6 + 0.4 * vn(P * 0.15));
	vec3 o = mix(paper.rgb * (0.96 + 0.04 * vn(P * 0.6)), ink.rgb, clamp(q * 0.9 + ln, 0.0, 1.0));
	if (seal) {
		vec2 S = tex_size / max(px_scale, 0.0001);
		float sz = S.y * 0.075;
		vec2 sc = S - vec2(sz * 1.9, sz * 1.7);
		vec2 d = abs(P - sc);
		float box = step(max(d.x, d.y), sz);
		float inner = step(max(d.x, d.y), sz * 0.82) * step(sz * 0.7, max(d.x, d.y));
		vec2 g = floor((P - sc + sz) / (sz * 0.28));
		float carve = step(0.55, h12(g + 3.0)) * step(max(d.x, d.y), sz * 0.66);
		float mott = 0.75 + 0.25 * vn(P * 0.4);
		float sv = box * (1.0 - inner) * (1.0 - carve) * mott;
		o = mix(o, seal_colour.rgb, sv * seal_colour.a);
	}
	COLOR = pm(o, c.a);
}
