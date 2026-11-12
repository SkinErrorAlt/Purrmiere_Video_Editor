shader_type canvas_item;
render_mode blend_disabled;

uniform int density = 16;
uniform float expansion = 0.0;
uniform float lock_amount = 100.0;

void fragment() {
	COLOR = texture(TEXTURE, UV);
}
