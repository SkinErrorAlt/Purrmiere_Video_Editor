shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);

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
	COLOR = sum / 16.0;
}
