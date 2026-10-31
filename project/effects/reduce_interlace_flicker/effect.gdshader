shader_type canvas_item;
render_mode blend_disabled;

uniform float softness : hint_range(0.0, 1.0) = 0.5;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec2 o = vec2(0.0, max(px_scale, 0.0001) / max(tex_size.y, 1.0));
	COLOR = texture(TEXTURE, UV) * (1.0 - softness * 0.5) + (texture(TEXTURE, UV + o) + texture(TEXTURE, UV - o)) * softness * 0.25;
}
