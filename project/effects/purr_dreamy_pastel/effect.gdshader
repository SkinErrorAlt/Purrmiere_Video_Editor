shader_type canvas_item;
render_mode blend_disabled;

uniform float pastel : hint_range(0.0, 1.0) = 0.7;
uniform vec4 shadow_tint : source_color = vec4(0.72, 0.68, 0.95, 1.0);
uniform vec4 high_tint : source_color = vec4(1.0, 0.86, 0.9, 1.0);
uniform float bloom : hint_range(0.0, 2.0) = 0.45;
uniform float bloom_size : hint_range(2.0, 80.0) = 22.0;
uniform float haze : hint_range(0.0, 1.0) = 0.12;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 s = unp(c);
	vec3 bl = vec3(0.0);
	for (int i = 0; i < 12; i++) {
		float an = float(i) * 0.5236 + 0.2;
		float rr = (i % 2 == 0) ? 1.0 : 0.5;
		vec3 t = unp(texture(TEXTURE, UV + vec2(cos(an), sin(an)) * TX(bloom_size * rr)));
		bl += max(t - 0.7, 0.0);
	}
	bl /= 12.0;
	float l = lum(s);
	vec3 g = mix(vec3(l), s, 1.0 - pastel * 0.45);
	vec3 tint = mix(shadow_tint.rgb, high_tint.rgb, smoothstep(0.1, 0.9, l));
	g = mix(g, g * 0.6 + tint * 0.5, pastel);
	g = g * (1.0 - pastel * 0.25) + shadow_tint.rgb * pastel * 0.18;
	g += bl * bloom * 2.0 * high_tint.rgb;
	g = mix(g, high_tint.rgb, haze * 0.3);
	COLOR = pm(g, c.a);
}
