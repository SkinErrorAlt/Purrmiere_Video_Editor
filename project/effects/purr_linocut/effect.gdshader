shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 ink : source_color = vec4(0.08, 0.07, 0.1, 1.0);
uniform vec4 paper : source_color = vec4(0.95, 0.92, 0.85, 1.0);
uniform float lines : hint_range(4.0, 80.0) = 30.0;
uniform float smooth_px : hint_range(0.0, 20.0) = 3.0;
uniform float contrast : hint_range(0.2, 3.0) = 1.3;
uniform float texture_amount : hint_range(0.0, 1.0) = 0.4;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float h = lum(unp(c)) * 2.0;
	for (int i = 0; i < 6; i++) {
		float an = float(i) * 1.0472;
		h += lum(unp(texture(TEXTURE, UV + vec2(cos(an), sin(an)) * TX(smooth_px))));
	}
	h /= 8.0;
	float l = clamp((h - 0.5) * contrast + 0.5, 0.0, 1.0);
	vec2 P = PX(UV);
	float v = h * lines + (vn(P * 0.02) - 0.5) * 0.15;
	float stripe = abs(fract(v) - 0.5) * 2.0;
	float carve = smoothstep(l + 0.08, l - 0.08, 1.0 - stripe);
	float k = 1.0 - max(carve, smoothstep(0.85, 0.95, l));
	k = max(k, smoothstep(0.12, 0.05, l));
	k *= 1.0 - texture_amount * 0.35 * vn(P * 0.5) * step(0.5, k);
	COLOR = pm(mix(paper.rgb, ink.rgb, clamp(k, 0.0, 1.0)), c.a);
}
