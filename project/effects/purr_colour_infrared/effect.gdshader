shader_type canvas_item;
render_mode blend_disabled;

uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float foliage : hint_range(0.0, 2.0) = 1.2;
uniform float halation : hint_range(0.0, 1.0) = 0.35;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 s = unp(c);
	float veg = clamp((s.g - max(s.r, s.b)) * 3.0, 0.0, 1.0);
	float ir = clamp(lum(s) * 0.8 + veg * foliage * 0.6 + s.r * 0.15, 0.0, 1.0);
	vec3 f = vec3(ir, s.r * 0.9, s.g * 0.85);
	f.b = mix(f.b, s.b * 1.1, smoothstep(0.1, 0.4, s.b - s.r));
	vec3 bl = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		float an = float(i) * 1.0472;
		bl += max(unp(texture(TEXTURE, UV + vec2(cos(an), sin(an)) * TX(10.0))) - 0.65, 0.0);
	}
	f += vec3(1.0, 0.6, 0.6) * lum(bl / 6.0) * halation * 2.0;
	COLOR = pm(mix(s, f, strength), c.a);
}
