shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 sun = vec2(0.82, 0.18);
uniform float warmth : hint_range(0.0, 1.0) = 0.7;
uniform float glow : hint_range(0.0, 2.0) = 0.8;
uniform float glow_size : hint_range(0.05, 2.0) = 0.7;
uniform float lift : hint_range(0.0, 0.5) = 0.08;
uniform float haze : hint_range(0.0, 1.0) = 0.3;
uniform vec4 sun_colour : source_color = vec4(1.0, 0.72, 0.35, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 s = unp(c);
	float asp = tex_size.x / max(tex_size.y, 1.0);
	float d = length((UV - sun) * vec2(asp, 1.0));
	vec3 g = s * mix(vec3(1.0), vec3(1.12, 1.0, 0.78), warmth);
	g = mix(g, g * g * (3.0 - 2.0 * g), 0.3 * warmth);
	g += sun_colour.rgb * lift * (1.0 - lum(s));
	float gl = exp(-d / max(glow_size * 0.35, 0.001)) * glow;
	g = 1.0 - (1.0 - g) * (1.0 - clamp(sun_colour.rgb * gl, 0.0, 1.0));
	g = mix(g, sun_colour.rgb * 0.9 + 0.1, haze * 0.35 * exp(-d * 1.5));
	COLOR = pm(g, c.a);
}
