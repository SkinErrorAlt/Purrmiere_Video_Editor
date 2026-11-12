shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D near_tex : filter_linear, repeat_disable;
uniform sampler2D mid_tex : filter_linear, repeat_disable;
uniform sampler2D glow_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float density : hint_range(0.0, 1.0) = 0.45;
uniform float folds : hint_range(0.0, 1.0) = 0.6;
uniform float fold_size : hint_range(20.0, 600.0) = 170.0;
uniform float fold_angle : hint_range(-180.0, 180.0) = 90.0;
uniform float softness : hint_range(0.0, 1.0) = 0.5;
uniform float glow : hint_range(0.0, 2.0) = 0.8;
uniform float room_light : hint_range(0.0, 1.0) = 0.35;
uniform float light_angle : hint_range(-180.0, 180.0) = -60.0;
uniform float weave : hint_range(0.0, 1.0) = 0.5;
uniform float weave_px : hint_range(1.5, 12.0) = 3.0;
uniform vec4 fabric : source_color = vec4(0.96, 0.95, 0.92, 1.0);
uniform int seed : hint_range(0, 999) = 8;


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
	float u = c / (fs * (0.6 + 0.35 * an)) + wobble;
	float prof = vq(vec2(u, a / (fs * 7.0) + sd)) * 0.82 + vq(vec2(u * 2.1 + 3.0, a / (fs * 3.5) + sd)) * 0.18;
	prof = 1.0 - pow(1.0 - clamp(prof, 0.0, 1.0), 1.8);
	float amp = 0.55 + 0.45 * smoothstep(0.0, 0.7, an);
	return prof * amp * fs * 0.5;
}

float threads(float x, float aa) {
	float v = 0.5 + 0.5 * cos(6.28318 * x);
	v = pow(v, 3.0);
	return mix(0.3125, v, clamp(1.6 - aa * 2.2, 0.0, 1.0));
}

void fragment() {
	vec4 src = texture(effect_tex, UV);
	vec2 full = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float ps = max(px_scale * full.x / max(tex_size.x, 1.0), 0.0001);
	vec2 Psz = full / ps;
	vec2 P = UV * Psz;
	vec2 Pc = Psz * 0.5;
	float sd = float(seed) * 2.37;
	float fa = radians(fold_angle);
	vec2 d = vec2(cos(fa), sin(fa));
	vec2 n2 = vec2(-d.y, d.x);
	float ext = abs(d.x) * Psz.x + abs(d.y) * Psz.y;
	float fs = max(fold_size, 1.0);
	float e = 1.5;
	float h0 = drape(P, Pc, d, n2, ext, fs, sd) * folds;
	float hpx = drape(P + vec2(e, 0.0), Pc, d, n2, ext, fs, sd) * folds;
	float hpy = drape(P + vec2(0.0, e), Pc, d, n2, ext, fs, sd) * folds;
	vec2 grad = vec2(hpx - h0, hpy - h0) / e;
	float slope = length(grad) * 3.0;
	float path = sqrt(1.0 + slope * slope);
	vec2 W = vec2(dot(P, d), dot(P, n2));
	float across = W.y + dot(grad, n2) * h0 * 0.9;
	float wp = max(weave_px, 0.5);
	float xa = W.x / wp;
	float xc = across / wp;
	float tw = threads(xa, fwidth(xa));
	float tc = threads(xc, fwidth(xc));
	float cover_thr = 1.0 - (1.0 - tw * 0.8) * (1.0 - tc * 0.8);
	float slub = 0.85 + 0.3 * vn(vec2(W.x / (wp * 40.0), W.y / (wp * 3.0)) + sd);
	float cov = clamp(density * path * slub * mix(1.0, cover_thr / 0.45, weave), 0.0, 1.0);
	vec3 sharp = unp(src);
	vec3 near = unp(texture(near_tex, UV));
	vec3 mid = unp(texture(mid_tex, UV));
	vec3 gl = unp(texture(glow_tex, UV));
	vec3 seen = mix(sharp, mix(near, mid, softness), clamp(softness * (0.4 + cov) * min(density * 4.0, 1.0), 0.0, 1.0));
	vec3 scatter = mix(mid, gl, 0.6);
	float la = radians(light_angle);
	vec3 L = normalize(vec3(cos(la) * 0.8, sin(la) * 0.8, 0.6));
	vec3 N = normalize(vec3(-grad * 2.2, 1.0));
	float shade = clamp((dot(N, L) + 0.3) / (L.z + 0.3), 0.0, 1.6);
	vec3 veil = fabric.rgb * room_light * shade + scatter * fabric.rgb * glow * 0.35;
	vec3 o = seen * (1.0 - cov) + veil * cov;
	float hot = smoothstep(0.25, 0.8, dot(gl, vec3(0.2126, 0.7152, 0.0722)));
	o += max(gl - seen, vec3(0.0)) * fabric.rgb * glow * 0.6 * hot * clamp(density * path * 1.5, 0.0, 1.0);
	COLOR = vec4(clamp(o, 0.0, 1.0) * src.a, src.a);
}
