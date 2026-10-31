shader_type canvas_item;
render_mode blend_disabled;

uniform float strength : hint_range(0.0, 1.0) = 0.7;
uniform float bleed : hint_range(0.0, 60.0) = 14.0;
uniform float warmth : hint_range(0.0, 1.0) = 0.4;
uniform float patchy : hint_range(0.0, 1.0) = 0.5;
uniform float contrast : hint_range(0.2, 3.0) = 1.15;
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

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 P = PX(UV);
	float l = clamp((lum(unp(c)) - 0.5) * contrast + 0.5, 0.0, 1.0);
	vec3 bw = vec3(l) * mix(vec3(1.0), vec3(1.06, 1.0, 0.86), warmth);
	vec2 w = vec2(fbm(P * 0.01), fbm(P * 0.01 + 4.4)) - 0.5;
	vec3 tc = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		float an = float(i) * 1.0472;
		tc += unp(texture(TEXTURE, UV + w * TX(bleed) * 3.0 + vec2(cos(an), sin(an)) * TX(bleed)));
	}
	tc /= 6.0;
	float tl = max(lum(tc), 0.05);
	vec3 tint = clamp(tc / tl, 0.0, 2.0);
	float m = strength * (1.0 - patchy * 0.6 + patchy * 0.6 * smoothstep(0.35, 0.65, fbm(P * 0.004)));
	vec3 o = bw * mix(vec3(1.0), tint, m);
	COLOR = pm(o, c.a);
}
