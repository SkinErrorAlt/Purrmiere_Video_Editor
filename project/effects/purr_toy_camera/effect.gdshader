shader_type canvas_item;
render_mode blend_disabled;

uniform int cast : hint_range(0, 2) = 0;
uniform float saturation : hint_range(0.0, 2.5) = 1.4;
uniform float contrast : hint_range(0.2, 3.0) = 1.2;
uniform float vignette : hint_range(0.0, 1.0) = 0.7;
uniform float soft : hint_range(0.0, 20.0) = 4.0;
uniform float leak : hint_range(0.0, 1.0) = 0.45;
uniform vec4 leak_colour : source_color = vec4(1.0, 0.4, 0.15, 1.0);
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }

void fragment() {
	vec2 q = UV - 0.5;
	float r = length(q * vec2(tex_size.x / max(tex_size.y, 1.0), 1.0));
	vec4 c = texture(TEXTURE, UV);
	vec4 acc = c;
	for (int i = 0; i < 6; i++) {
		float an = float(i) * 1.0472;
		acc += texture(TEXTURE, UV + vec2(cos(an), sin(an)) * TX(soft * r * 2.0));
	}
	acc /= 7.0;
	vec3 s = unp(acc);
	s = clamp((s - 0.5) * contrast + 0.5, 0.0, 1.0);
	s = mix(vec3(lum(s)), s, saturation);
	if (cast == 0) {
		s = vec3(smoothstep(0.05, 0.95, s.r), s.g * 1.05 + 0.03, s.b * 0.8 + 0.12);
	} else if (cast == 1) {
		s *= vec3(1.1, 1.0, 0.82);
	} else {
		s *= vec3(0.88, 1.0, 1.12);
	}
	s *= 1.0 - vignette * smoothstep(0.3, 0.95, r);
	vec2 hs = h22(vec2(float(seed), 3.0));
	vec2 lp = hs.x < 0.5 ? vec2(hs.y < 0.5 ? 0.0 : 1.0, hs.x * 2.0) : vec2(hs.x * 2.0 - 1.0, hs.y < 0.5 ? 0.0 : 1.0);
	float ld = length((UV - lp) * vec2(tex_size.x / max(tex_size.y, 1.0), 1.0));
	float lk = exp(-ld * 3.0) * leak * (0.8 + 0.2 * vn(UV * 6.0 + float(seed)));
	s = 1.0 - (1.0 - s) * (1.0 - clamp(leak_colour.rgb * lk * 1.5, 0.0, 1.0));
	COLOR = pm(s, c.a);
}
