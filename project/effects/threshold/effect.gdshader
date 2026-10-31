shader_type canvas_item;
render_mode blend_disabled;

uniform float level : hint_range(0.0, 1.0) = 0.5;
uniform float softness : hint_range(0.0, 1.0) = 0.05;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	float l = dot(rgb, LUMA);
	float s = max(softness, 0.0005);
	float v = smoothstep(level - s * 0.5, level + s * 0.5, l);
	COLOR = vec4(vec3(v) * c.a, c.a);
}
