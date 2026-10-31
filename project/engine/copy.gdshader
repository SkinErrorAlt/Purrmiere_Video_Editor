shader_type canvas_item;
render_mode blend_disabled;

uniform bool premultiply = false;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (premultiply) {
		c = vec4(c.rgb * c.a, c.a);
	}
	COLOR = c;
}
