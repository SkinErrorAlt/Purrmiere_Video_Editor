shader_type canvas_item;
render_mode blend_disabled;

uniform int source : hint_range(0, 1) = 0;
uniform sampler2D picture : filter_linear, hint_default_white;
uniform float near_line : hint_range(0.0, 1.0) = 0.95;
uniform float far_line : hint_range(0.0, 1.0) = 0.35;
uniform float density : hint_range(0.0, 3.0) = 0.8;
uniform vec4 colour : source_color = vec4(0.75, 0.82, 0.9, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	float d;
	if (source == 1) {
		d = 1.0 - dot(texture(picture, UV).rgb, vec3(0.299, 0.587, 0.114));
	} else {
		float span = far_line - near_line;
		d = abs(span) > 0.0001 ? clamp((UV.y - near_line) / span, 0.0, 1.0) : step(far_line, UV.y);
		d = d * d * (3.0 - 2.0 * d);
	}
	float hz = (1.0 - exp(-density * d * 2.5)) * colour.a;
	vec3 o = mix(rgb, colour.rgb, hz);
	COLOR = vec4(clamp(o, 0.0, 1.0) * c.a, c.a);
}
