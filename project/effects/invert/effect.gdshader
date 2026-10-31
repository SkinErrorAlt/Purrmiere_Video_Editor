shader_type canvas_item;
render_mode blend_disabled;

uniform bool invert_r = true;
uniform bool invert_g = true;
uniform bool invert_b = true;
uniform bool invert_a = false;
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec3 inv = vec3(invert_r ? 1.0 - rgb.r : rgb.r, invert_g ? 1.0 - rgb.g : rgb.g, invert_b ? 1.0 - rgb.b : rgb.b);
	rgb = mix(rgb, inv, amount);
	float a = invert_a ? mix(c.a, 1.0 - c.a, amount) : c.a;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
