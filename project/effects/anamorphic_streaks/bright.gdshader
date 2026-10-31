shader_type canvas_item;
render_mode blend_disabled;

uniform float threshold : hint_range(0.0, 1.0) = 0.75;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float l = dot(clamp(rgb, 0.0, 1.0), LUMA);
	float w = clamp((l - threshold) / max(1.0 - threshold, 0.05), 0.0, 1.0);
	w = w * w * (3.0 - 2.0 * w);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * w * a, w * a);
}
