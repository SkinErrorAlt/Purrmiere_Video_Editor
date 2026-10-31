shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform float flare : hint_range(0.0, 2.0) = 0.8;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	float p = clamp(progress, 0.0, 1.0);
	vec3 o = rgb + rgb * flare * sin(p * 3.14159265) + vec3(flare * 0.25 * sin(p * 3.14159265));
	float a = c.a * (1.0 - smoothstep(0.3, 1.0, p));
	COLOR = vec4(clamp(o, 0.0, 1.0) * a, a);
}
