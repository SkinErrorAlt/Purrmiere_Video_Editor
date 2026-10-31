shader_type canvas_item;
render_mode blend_disabled;

uniform float red_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float green_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float blue_threshold : hint_range(0.0, 1.0) = 0.5;
uniform bool invert_red = false;
uniform bool invert_green = false;
uniform bool invert_blue = false;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 v = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 on = step(vec3(red_threshold, green_threshold, blue_threshold), v);
	vec3 flip = vec3(invert_red ? 1.0 : 0.0, invert_green ? 1.0 : 0.0, invert_blue ? 1.0 : 0.0);
	on = abs(on - flip);
	COLOR = vec4(on * a, a);
}
