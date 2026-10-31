shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 tint : source_color = vec4(0.62, 0.57, 0.48, 1.0);
uniform float contrast : hint_range(0.2, 3.0) = 1.35;
uniform float sheen : hint_range(0.0, 1.0) = 0.35;
uniform float edges : hint_range(0.0, 1.0) = 0.6;
uniform float scratches : hint_range(0.0, 1.0) = 0.4;
uniform float swirl : hint_range(0.0, 1.0) = 0.5;
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

void fragment() {
	vec2 q = UV - 0.5;
	float r = length(q);
	vec2 tg = vec2(-q.y, q.x);
	vec4 c = texture(TEXTURE, UV);
	vec4 acc = c;
	for (int i = 1; i <= 4; i++) {
		float o = (float(i) - 2.5) * swirl * 0.006 * r * r * 4.0;
		acc += texture(TEXTURE, UV + tg * o * 4.0);
	}
	acc /= 5.0;
	float l = lum(unp(acc));
	l = clamp((l - 0.5) * contrast + 0.5, 0.0, 1.0);
	l = l * l * (3.0 - 2.0 * l);
	vec3 o = tint.rgb * (0.08 + l * 1.1);
	o += vec3(sheen * 0.25 * pow(max(0.0, 1.0 - abs(UV.x + UV.y - 0.7) * 1.5), 3.0));
	vec2 P = PX(UV);
	float ox = fbm(P * 0.008) * 0.25 + fbm(P * 0.03) * 0.1;
	vec2 e = min(UV, 1.0 - UV);
	float edge = smoothstep(0.0, 0.12 + ox * 0.5, min(e.x, e.y) * 1.6 + 0.02 - edges * 0.05);
	o *= mix(1.0, edge * (0.85 + 0.15 * vn(P * 0.1)), edges);
	vec2 sp = rot(0.35) * P;
	float lineid = floor(sp.x / 3.0);
	float sc = step(0.985, h12(vec2(lineid, 1.0))) * step(vn(vec2(lineid, sp.y * 0.004)), 0.6) * scratches;
	o = mix(o, tint.rgb * 1.2, sc * 0.6);
	COLOR = pm(o, c.a);
}
