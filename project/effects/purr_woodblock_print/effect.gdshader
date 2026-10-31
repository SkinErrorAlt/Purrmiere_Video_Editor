shader_type canvas_item;
render_mode blend_disabled;

uniform float outline : hint_range(0.0, 6.0) = 1.8;
uniform float threshold : hint_range(0.0, 1.0) = 0.25;
uniform float grain : hint_range(0.0, 1.0) = 0.45;
uniform float sky_fade : hint_range(0.0, 1.0) = 0.4;
uniform vec4 sky : source_color = vec4(0.15, 0.22, 0.4, 1.0);
uniform vec4 paper : source_color = vec4(0.94, 0.9, 0.8, 1.0);
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

const vec3 WB[8] = vec3[](vec3(0.15, 0.22, 0.38), vec3(0.24, 0.4, 0.58), vec3(0.83, 0.32, 0.22), vec3(0.86, 0.66, 0.32), vec3(0.5, 0.6, 0.44), vec3(0.94, 0.9, 0.8), vec3(0.13, 0.11, 0.1), vec3(0.9, 0.66, 0.6));

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 s = unp(c);
	vec3 best = WB[0];
	float bd = 99.0;
	for (int i = 0; i < 8; i++) {
		vec3 d = s - WB[i];
		float dd = dot(d, d);
		if (dd < bd) {
			bd = dd;
			best = WB[i];
		}
	}
	vec2 P = PX(UV);
	float wg = fbm(vec2(P.x * 0.004, P.y * 0.06));
	vec3 o = mix(paper.rgb, best, 0.9 - grain * 0.3 + grain * 0.4 * wg);
	o = mix(o, sky.rgb, sky_fade * smoothstep(0.35, 0.0, UV.y) * 0.8);
	float e = edg(TEXTURE, UV, TX(max(outline, 0.01)));
	float k = smoothstep(threshold, threshold + 0.15, e) * step(0.01, outline);
	o = mix(o, WB[6], k * (0.85 + 0.15 * vn(P * 0.2)));
	o *= 0.96 + 0.04 * vn(P * 0.7);
	COLOR = pm(o, c.a);
}
