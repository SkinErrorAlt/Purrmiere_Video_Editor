shader_type canvas_item;
render_mode blend_disabled;

uniform float folds : hint_range(0.0, 1.0) = 0.6;
uniform float fold_size : hint_range(20.0, 600.0) = 240.0;
uniform float fold_angle : hint_range(-180.0, 180.0) = 90.0;
uniform float fan : hint_range(0.0, 1.0) = 0.3;
uniform float displace : hint_range(0.0, 1.0) = 0.5;
uniform float light_angle : hint_range(-180.0, 180.0) = -50.0;
uniform float sheen : hint_range(0.0, 2.0) = 1.0;
uniform float gloss : hint_range(0.0, 1.0) = 0.6;
uniform float shadow : hint_range(0.0, 1.0) = 0.55;
uniform float weave : hint_range(0.0, 1.0) = 0.4;
uniform int seed : hint_range(0, 999) = 2;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vq(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }

float drape(vec2 P, vec2 Pc, vec2 d, vec2 n, float ext, float fs, float sd) {
	vec2 rp = P - Pc;
	float a = dot(rp, d) + ext * 0.5;
	float an = clamp(a / max(ext, 1.0), 0.0, 1.0);
	float c = dot(rp, n);
	float wobble = (vn(vec2(a / (fs * 3.5), c / (fs * 4.0)) + sd) - 0.5) * 1.5 + (vn(vec2(a / (fs * 2.0), c / (fs * 2.5)) + sd + 5.0) - 0.5) * 0.35;
	float u = c / (fs * (0.55 + fan * 1.7 * an)) + wobble;
	float prof = vq(vec2(u, a / (fs * 7.0) + sd)) * 0.82 + vq(vec2(u * 2.1 + 3.0, a / (fs * 3.5) + sd)) * 0.18;
	float amp = 0.45 + 0.55 * smoothstep(0.0, 0.7, an);
	float sag = (vq(rp / (fs * 1.8) + sd + 9.0) - 0.5) * 0.25;
	prof = 1.0 - pow(1.0 - clamp(prof, 0.0, 1.0), 1.8);
	return (prof * amp + sag) * fs * 0.5;
}

void fragment() {
	vec2 ts = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 Psz = ts / ps;
	vec2 P = UV * Psz;
	vec2 Pc = Psz * 0.5;
	float sd = float(seed) * 2.93;
	float fa = radians(fold_angle);
	vec2 d = vec2(cos(fa), sin(fa));
	vec2 n2 = vec2(-d.y, d.x);
	float ext = abs(d.x) * Psz.x + abs(d.y) * Psz.y;
	float fs = max(fold_size, 1.0);
	float e = 1.5;
	float k = folds;
	float h0 = drape(P, Pc, d, n2, ext, fs, sd) * k;
	float hpx = drape(P + vec2(e, 0.0), Pc, d, n2, ext, fs, sd) * k;
	float hpy = drape(P + vec2(0.0, e), Pc, d, n2, ext, fs, sd) * k;
	vec2 grad = vec2(hpx - h0, hpy - h0) / e;
	vec2 off = -grad * displace * fs * 0.12;
	vec2 uv = UV + off * ps / ts;
	vec4 c0 = texture(TEXTURE, UV);
	vec3 dye = unp(texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0))));
	vec3 N = normalize(vec3(-grad * 2.2, 1.0));
	float la = radians(light_angle);
	vec3 L = normalize(vec3(cos(la) * 0.8, sin(la) * 0.8, 0.6));
	vec3 V = vec3(0.0, 0.0, 1.0);
	vec3 Hv = normalize(L + V);
	vec3 T = vec3(d, 0.0);
	T = normalize(T - N * dot(N, T));
	vec3 B = cross(N, T);
	float ax = mix(0.7, 0.35, gloss);
	float ay = mix(0.3, 0.07, gloss);
	float hx = dot(Hv, T) / ax;
	float hy = dot(Hv, B) / ay;
	float hz = max(dot(Hv, N), 0.05);
	vec2 W = vec2(dot(P, d), dot(P, n2));
	float wv = vn(vec2(W.x / 7.0, W.y / 1.3) + sd) * 0.6 + vn(vec2(W.x / 3.0, W.y / 0.9) + sd + 3.0) * 0.4;
	float spec = exp(-(hx * hx + hy * hy) / (hz * hz)) * (1.0 - weave * 0.45 + weave * 0.9 * wv) * mix(0.55, 0.8, gloss);
	float broad = exp(-(hx * hx * 0.1 + hy * hy * 0.04) / (hz * hz)) * 0.12;
	float ndl = dot(N, L);
	float diff = clamp((ndl + 0.35) / 1.35, 0.0, 1.0);
	float flat_d = clamp((L.z + 0.35) / 1.35, 0.0, 1.0);
	float hn = h0 / max(fs * 0.5 * max(k, 0.0001), 0.0001);
	float ao = mix(1.0, smoothstep(0.0, 0.8, hn) * 0.75 + 0.25, shadow * step(0.0001, k));
	float on = step(0.0001, k);
	float shade = mix(1.0, (0.12 + 0.88 * diff / max(flat_d, 0.001)) * ao * (0.92 - 0.08 * sheen), on);
	vec3 hl = mix(dye, vec3(1.0), 0.5);
	vec3 o = dye * shade + hl * (spec + broad) * sheen * on * (0.5 + 0.5 * ao);
	COLOR = vec4(clamp(o, 0.0, 1.0) * c0.a, c0.a);
}
