shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D mask_tex : filter_linear, repeat_disable;

void fragment() {
	float m = texture(mask_tex, UV).a;
	COLOR = texture(TEXTURE, UV) * m;
}
