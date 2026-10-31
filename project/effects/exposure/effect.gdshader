shader_type canvas_item;
render_mode blend_disabled;

uniform float stops : hint_range(-8.0, 8.0) = 0.0;
uniform float offset : hint_range(-0.5, 0.5) = 0.0;
uniform float gamma_v : hint_range(0.1, 4.0) = 1.0;
uniform bool per_channel = false;
uniform float stops_r : hint_range(-8.0, 8.0) = 0.0;
uniform float stops_g : hint_range(-8.0, 8.0) = 0.0;
uniform float stops_b : hint_range(-8.0, 8.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 gain = vec3(exp2(stops));
	if (per_channel) {
		gain *= vec3(exp2(stops_r), exp2(stops_g), exp2(stops_b));
	}
	rgb = rgb * gain + vec3(offset);
	rgb = pow(max(rgb, vec3(0.0)), vec3(1.0 / max(gamma_v, 0.0001)));
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
