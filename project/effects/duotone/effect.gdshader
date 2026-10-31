shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 dark : source_color = vec4(0.05, 0.08, 0.25, 1.0);
uniform vec4 light : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform float low : hint_range(0.0, 1.0) = 0.0;
uniform float high : hint_range(0.0, 1.0) = 1.0;
uniform float contrast : hint_range(0.1, 4.0) = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	float t = clamp((luma - low) / max(high - low, 0.0001), 0.0, 1.0);
	t = pow(t, 1.0 / max(contrast, 0.0001));
	rgb = mix(dark.rgb, light.rgb, t);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
