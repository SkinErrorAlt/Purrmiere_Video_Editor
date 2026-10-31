shader_type canvas_item;
render_mode blend_disabled;

uniform float threshold : hint_range(0.0, 1.0) = 0.85;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	float l = max(dot(rgb, LUMA), max(rgb.r, max(rgb.g, rgb.b)) * 0.85);
	float lo = clamp(threshold, 0.0, 0.999);
	float w = smoothstep(lo - 0.04, min(lo + 0.08, 1.0) + 0.0001, l);
	COLOR = vec4(rgb * w * a, w * a);
}
