shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	if (a < 0.002) {
		COLOR = vec4(0.0);
	} else {
		vec3 matted = clamp(c.rgb / a, 0.0, 1.0);
		vec3 straight = (matted - (1.0 - a) * background.rgb) / a;
		COLOR = vec4(clamp(straight, 0.0, 1.0) * a, a);
	}
}
