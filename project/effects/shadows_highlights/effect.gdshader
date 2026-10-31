shader_type canvas_item;
render_mode blend_disabled;

uniform float shadows : hint_range(-1.0, 1.0) = 0.3;
uniform float highlights : hint_range(-1.0, 1.0) = -0.2;
uniform float shadow_reach : hint_range(0.05, 1.0) = 0.35;
uniform float highlight_reach : hint_range(0.05, 1.0) = 0.35;
uniform float mid_contrast : hint_range(-1.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float luma = clamp(dot(rgb, vec3(0.2126, 0.7152, 0.0722)), 0.0, 1.0);
	float s_mask = 1.0 - smoothstep(0.0, max(shadow_reach, 0.0001), luma);
	float h_mask = smoothstep(1.0 - max(highlight_reach, 0.0001), 1.0, luma);
	float m_mask = 1.0 - s_mask - h_mask;
	float lift = shadows * s_mask * 0.5 + highlights * h_mask * 0.5;
	rgb += vec3(lift);
	if (abs(mid_contrast) > 0.0001) {
		rgb = mix(rgb, (rgb - 0.5) * (1.0 + mid_contrast) + 0.5, clamp(m_mask, 0.0, 1.0));
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
