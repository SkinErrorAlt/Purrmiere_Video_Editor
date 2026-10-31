shader_type canvas_item;
render_mode blend_disabled;

uniform float low : hint_range(0.0, 1.0) = 0.05;
uniform float high : hint_range(0.0, 1.0) = 0.85;
uniform float contrast : hint_range(0.1, 4.0) = 1.0;
uniform bool invert = false;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	float t = clamp((luma - low) / max(high - low, 0.0001), 0.0, 1.0);
	t = pow(t, 1.0 / max(contrast, 0.0001));
	if (invert) { t = 1.0 - t; }
	vec3 heat;
	if (t < 0.25) {
		heat = mix(vec3(0.0, 0.0, 0.12), vec3(0.35, 0.0, 0.6), t / 0.25);
	} else if (t < 0.5) {
		heat = mix(vec3(0.35, 0.0, 0.6), vec3(0.95, 0.15, 0.1), (t - 0.25) / 0.25);
	} else if (t < 0.75) {
		heat = mix(vec3(0.95, 0.15, 0.1), vec3(1.0, 0.85, 0.1), (t - 0.5) / 0.25);
	} else {
		heat = mix(vec3(1.0, 0.85, 0.1), vec3(1.0, 1.0, 1.0), (t - 0.75) / 0.25);
	}
	rgb = heat;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
