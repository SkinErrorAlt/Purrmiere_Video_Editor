shader_type canvas_item;
render_mode blend_disabled;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(1.0);
	float l = dot(rgb, LUMA);
	float open = smoothstep(0.08, 0.38, l);
	open = mix(1.0, open, a);
	COLOR = vec4(vec3(open), 1.0);
}
