shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform vec4 colour : source_color = vec4(1.0, 0.4, 0.1, 1.0);
uniform vec2 tex_size;
uniform float clip_time;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float band = 0.5 + 0.5 * sin(UV.y * tex_size.y * 0.1 + clip_time * 4.0);
	COLOR = vec4(mix(c.rgb, colour.rgb * c.a, strength * band), c.a);
}
