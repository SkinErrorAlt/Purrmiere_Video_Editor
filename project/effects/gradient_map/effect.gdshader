shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 c0 : source_color = vec4(0.02, 0.02, 0.08, 1.0);
uniform vec4 c1 : source_color = vec4(0.3, 0.1, 0.3, 1.0);
uniform vec4 c2 : source_color = vec4(0.9, 0.45, 0.2, 1.0);
uniform vec4 c3 : source_color = vec4(1.0, 0.97, 0.85, 1.0);
uniform float blend : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float luma = clamp(dot(rgb, vec3(0.2126, 0.7152, 0.0722)), 0.0, 1.0);
	float t = luma * 3.0;
	vec3 ramp;
	if (t < 1.0) {
		ramp = mix(c0.rgb, c1.rgb, t);
	} else if (t < 2.0) {
		ramp = mix(c1.rgb, c2.rgb, t - 1.0);
	} else {
		ramp = mix(c2.rgb, c3.rgb, t - 2.0);
	}
	rgb = mix(rgb, ramp, blend);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
