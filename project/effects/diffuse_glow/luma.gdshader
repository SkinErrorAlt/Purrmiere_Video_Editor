shader_type canvas_item;
render_mode blend_disabled;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	float l = dot(rgb, LUMA);
	COLOR = vec4(vec3(l * a), a);
}
