shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float block : hint_range(1.0, 200.0) = 8.0;

void fragment() {
	float b = max(block * px_scale, 1.0);
	vec2 cells = tex_size / b;
	vec2 uv = (floor(UV * cells) + 0.5) / cells;
	COLOR = texture(TEXTURE, uv);
}
