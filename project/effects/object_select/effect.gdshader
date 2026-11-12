shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int show : hint_range(0, 1) = 0;
uniform vec4 matte_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float dim : hint_range(0.0, 1.0) = 0.0;
uniform bool spill_out = false;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	if (show == 1) {
		COLOR = vec4(matte_colour.rgb, 1.0) * src.a * matte_colour.a;
	} else {
		COLOR = vec4(src.rgb * (1.0 - dim), src.a);
	}
}
