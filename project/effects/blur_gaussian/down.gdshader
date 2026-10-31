shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);

void fragment() {
	vec2 px = 1.0 / tex_size;
	vec4 a = texture(TEXTURE, UV + px * vec2(-0.5, -0.5));
	vec4 b = texture(TEXTURE, UV + px * vec2(0.5, -0.5));
	vec4 c = texture(TEXTURE, UV + px * vec2(-0.5, 0.5));
	vec4 d = texture(TEXTURE, UV + px * vec2(0.5, 0.5));
	COLOR = (a + b + c + d) * 0.25;
}
