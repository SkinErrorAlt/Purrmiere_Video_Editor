shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);

void fragment() {
	vec2 e = 0.5 / max(tex_size, vec2(1.0));
	vec4 s = texture(TEXTURE, UV + vec2(-e.x, -e.y));
	s += texture(TEXTURE, UV + vec2(e.x, -e.y));
	s += texture(TEXTURE, UV + vec2(-e.x, e.y));
	s += texture(TEXTURE, UV + vec2(e.x, e.y));
	COLOR = s * 0.25;
}
