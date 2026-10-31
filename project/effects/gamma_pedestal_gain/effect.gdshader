shader_type canvas_item;
render_mode blend_disabled;

uniform float black_stretch : hint_range(0.0, 4.0) = 0.0;
uniform float red_gamma : hint_range(0.1, 4.0) = 0.9;
uniform float red_pedestal : hint_range(-1.0, 1.0) = 0.0;
uniform float red_gain : hint_range(0.0, 4.0) = 1.05;
uniform float green_gamma : hint_range(0.1, 4.0) = 1.0;
uniform float green_pedestal : hint_range(-1.0, 1.0) = 0.0;
uniform float green_gain : hint_range(0.0, 4.0) = 1.0;
uniform float blue_gamma : hint_range(0.1, 4.0) = 1.15;
uniform float blue_pedestal : hint_range(-1.0, 1.0) = 0.0;
uniform float blue_gain : hint_range(0.0, 4.0) = 0.95;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 v = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 low = 1.0 - v;
	v = clamp(v + max(black_stretch, 0.0) * 0.6 * v * low * low * low, 0.0, 1.0);
	vec3 g = max(vec3(red_gamma, green_gamma, blue_gamma), vec3(0.01));
	vec3 outc = vec3(red_pedestal, green_pedestal, blue_pedestal) + vec3(red_gain, green_gain, blue_gain) * pow(v, g);
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
