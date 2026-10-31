shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 ink_1 : source_color = vec4(1.0, 0.82, 0.2, 1.0);
uniform vec4 ink_2 : source_color = vec4(0.95, 0.3, 0.52, 1.0);
uniform vec4 ink_3 : source_color = vec4(0.12, 0.1, 0.26, 1.0);
uniform vec4 paper : source_color = vec4(0.97, 0.95, 0.9, 1.0);
uniform float cut_1 : hint_range(0.0, 1.0) = 0.78;
uniform float cut_2 : hint_range(0.0, 1.0) = 0.52;
uniform float cut_3 : hint_range(0.0, 1.0) = 0.28;
uniform float offset : hint_range(0.0, 30.0) = 5.0;
uniform float texture_amount : hint_range(0.0, 1.0) = 0.45;
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }

float layer(sampler2D tx, vec2 uv, float cut, vec2 P, float k) {
	float l = lum(unp(texture(tx, uv)));
	float v = smoothstep(cut + 0.02, cut - 0.02, l);
	float mesh = 0.5 + 0.5 * sin(P.x * 1.9) * sin(P.y * 1.9);
	float voids = smoothstep(0.75, 0.85, vn(P * 0.12 + k * 13.1 + float(seed)));
	return v * (1.0 - texture_amount * (mesh * 0.25 + voids * 0.8));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 P = PX(UV);
	vec2 o1 = (h22(vec2(float(seed), 1.0)) - 0.5) * 2.0 * TX(offset);
	vec2 o2 = (h22(vec2(float(seed), 2.0)) - 0.5) * 2.0 * TX(offset);
	vec2 o3 = (h22(vec2(float(seed), 3.0)) - 0.5) * 2.0 * TX(offset);
	vec3 o = paper.rgb;
	o = mix(o, ink_1.rgb, layer(TEXTURE, UV + o1, cut_1, P, 1.0) * ink_1.a);
	o = mix(o, ink_2.rgb, layer(TEXTURE, UV + o2, cut_2, P, 2.0) * ink_2.a);
	o = mix(o, ink_3.rgb, layer(TEXTURE, UV + o3, cut_3, P, 3.0) * ink_3.a);
	COLOR = pm(o, c.a);
}
