shader_type canvas_item;
render_mode blend_disabled;

uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform vec3 weights = vec3(0.299, 0.587, 0.114);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec3 w = weights / max(weights.r + weights.g + weights.b, 0.0001);
	float l = dot(rgb, w);
	rgb = mix(rgb, vec3(l), amount);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * c.a, c.a);
}
