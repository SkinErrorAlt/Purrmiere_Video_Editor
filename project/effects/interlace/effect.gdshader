shader_type canvas_item;
render_mode blend_disabled;

uniform float offset : hint_range(0.0, 60.0) = 6.0;
uniform float field_darken : hint_range(0.0, 1.0) = 0.1;
uniform float line_height : hint_range(1.0, 16.0) = 1.0;
uniform bool second_field = false;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float lh = max(line_height * max(px_scale, 0.0001), 1.0);
	float band = floor(UV.y * size.y / lh);
	bool odd = mod(band, 2.0) >= 1.0;
	bool move_it = second_field ? !odd : odd;
	float dx = move_it ? offset * max(px_scale, 0.0001) / size.x : 0.0;
	vec4 c = texture(TEXTURE, clamp(UV + vec2(dx, 0.0), vec2(0.0), vec2(1.0)));
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	if (move_it) {
		rgb *= 1.0 - field_darken;
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
