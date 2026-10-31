shader_type canvas_item;
render_mode blend_disabled;

uniform float threshold : hint_range(0.0, 1.0) = 0.6;
uniform float knee : hint_range(0.0, 1.0) = 0.3;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, LUMA);
	float k = max(knee * threshold, 0.0001);
	float soft = clamp(l - threshold + k, 0.0, 2.0 * k);
	soft = soft * soft / (4.0 * k);
	float contribution = max(soft, l - threshold) / max(l, 0.0001);
	COLOR = c * contribution;
}
