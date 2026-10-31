shader_type canvas_item;
render_mode blend_disabled;

uniform int layers : hint_range(2, 8) = 4;
uniform float tint : hint_range(0.0, 1.0) = 0.55;
uniform vec4 card : source_color = vec4(0.72, 0.55, 0.36, 1.0);
uniform float edge : hint_range(0.0, 10.0) = 2.5;
uniform float shadow : hint_range(0.0, 1.0) = 0.5;
uniform float shadow_len : hint_range(0.0, 30.0) = 7.0;
uniform float light_angle : hint_range(-180.0, 180.0) = -135.0;
uniform float corrugation : hint_range(0.0, 1.0) = 0.35;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }

float lev(sampler2D tx, vec2 uv) {
	return floor(lum(unp(texture(tx, uv))) * float(layers) * 0.999);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 s = unp(c);
	float L = lev(TEXTURE, UV);
	float la = radians(light_angle);
	vec2 dir = vec2(cos(la), sin(la));
	float sh = 0.0;
	for (int i = 1; i <= 4; i++) {
		sh = max(sh, step(L + 0.5, lev(TEXTURE, UV + dir * TX(shadow_len * float(i) * 0.25))) * (1.0 - float(i - 1) * 0.18));
	}
	float rimv = step(lev(TEXTURE, UV - dir * TX(edge)), L - 0.5);
	vec3 base = (L + 0.5) / float(layers) * mix(s / max(lum(s), 0.05) * 0.8, card.rgb * 1.4, tint);
	vec2 P = PX(UV);
	float corr = 0.5 + 0.5 * sin(P.x * 0.9 + L * 2.0);
	base *= 1.0 - corrugation * 0.12 * corr - 0.08 * (vn(P * 0.3) - 0.5);
	base = mix(base, card.rgb * 1.25, rimv * step(0.01, edge));
	base *= 1.0 - sh * shadow * 0.55;
	COLOR = pm(base, c.a);
}
