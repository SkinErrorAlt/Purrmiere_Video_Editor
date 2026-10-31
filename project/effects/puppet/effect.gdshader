shader_type canvas_item;
render_mode blend_disabled;

uniform int density = 16;

void fragment() {
	COLOR = texture(TEXTURE, UV);
}
