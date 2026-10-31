shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform sampler2D level_tex : filter_linear, repeat_disable;
uniform float radius : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 px = 1.0 / tex_size;
	vec4 sum = texture(TEXTURE, UV) * 4.0;
	sum += texture(TEXTURE, UV + px * vec2(-1.0, 0.0)) * 2.0;
	sum += texture(TEXTURE, UV + px * vec2(1.0, 0.0)) * 2.0;
	sum += texture(TEXTURE, UV + px * vec2(0.0, -1.0)) * 2.0;
	sum += texture(TEXTURE, UV + px * vec2(0.0, 1.0)) * 2.0;
	sum += texture(TEXTURE, UV + px * vec2(-1.0, -1.0));
	sum += texture(TEXTURE, UV + px * vec2(1.0, -1.0));
	sum += texture(TEXTURE, UV + px * vec2(-1.0, 1.0));
	sum += texture(TEXTURE, UV + px * vec2(1.0, 1.0));
	vec4 up = sum / 16.0;
	COLOR = up * mix(0.6, 1.4, radius) + texture(level_tex, UV);
}
