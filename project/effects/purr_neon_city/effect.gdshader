shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 cyan : source_color = vec4(0.1, 0.8, 1.0, 1.0);
uniform vec4 magenta : source_color = vec4(1.0, 0.2, 0.75, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.8;
uniform float crush : hint_range(0.0, 1.0) = 0.3;
uniform float bloom : hint_range(0.0, 2.0) = 0.7;
uniform float bloom_size : hint_range(2.0, 80.0) = 18.0;
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
		float an = float(i) * 0.5236;
		float rr = (i % 2 == 0) ? 1.0 : 0.45;
		bl += max(unp(texture(TEXTURE, UV + vec2(cos(an), sin(an)) * TX(bloom_size * rr))) - 0.6, 0.0);
	}
	bl /= 12.0;
	float l = lum(s);
	vec3 tint = mix(cyan.rgb, magenta.rgb, smoothstep(0.25, 0.75, l));
	vec3 g = mix(s, tint * (l * 1.3 + 0.05), strength * 0.7);
	g = mix(g, g * smoothstep(0.0, 0.6, l), crush);
	g += bl * bloom * 2.0 * mix(magenta.rgb, cyan.rgb, 0.3);
	COLOR = pm(g, c.a);
}
