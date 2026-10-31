shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D a_tex : filter_linear, repeat_disable;
uniform sampler2D b_tex : filter_linear, repeat_disable;
uniform float w = 0.0;

void fragment() {
	COLOR = mix(texture(a_tex, UV), texture(b_tex, UV), w);
}
