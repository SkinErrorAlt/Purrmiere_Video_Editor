shader_type canvas_item;
render_mode blend_disabled;

uniform float r_from_r : hint_range(-2.0, 2.0) = 1.0;
uniform float r_from_g : hint_range(-2.0, 2.0) = 0.0;
uniform float r_from_b : hint_range(-2.0, 2.0) = 0.0;
uniform float g_from_r : hint_range(-2.0, 2.0) = 0.0;
uniform float g_from_g : hint_range(-2.0, 2.0) = 1.0;
uniform float g_from_b : hint_range(-2.0, 2.0) = 0.0;
uniform float b_from_r : hint_range(-2.0, 2.0) = 0.0;
uniform float b_from_g : hint_range(-2.0, 2.0) = 0.0;
uniform float b_from_b : hint_range(-2.0, 2.0) = 1.0;
uniform bool monochrome = false;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 o;
	o.r = dot(rgb, vec3(r_from_r, r_from_g, r_from_b));
	o.g = dot(rgb, vec3(g_from_r, g_from_g, g_from_b));
	o.b = dot(rgb, vec3(b_from_r, b_from_g, b_from_b));
	if (monochrome) {
		o = vec3(o.r);
	}
	rgb = o;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
