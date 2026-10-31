shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 black_to : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 white_to : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 1.0;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	float l = dot(rgb, LUMA);
	vec3 t = mix(black_to.rgb, white_to.rgb, l);
	rgb = mix(rgb, t, amount);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * c.a, c.a);
}
