shader_type canvas_item;
render_mode blend_disabled;

uniform float threshold : hint_range(0.0, 1.0) = 0.1;
uniform float softness : hint_range(0.0, 1.0) = 0.05;
uniform bool invert = false;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	float l = dot(rgb, LUMA);
	float m = smoothstep(threshold, threshold + max(softness, 0.001), l);
	if (invert) {
		m = 1.0 - m;
	}
	float a = c.a * m;
	COLOR = vec4(rgb * a, a);
}
