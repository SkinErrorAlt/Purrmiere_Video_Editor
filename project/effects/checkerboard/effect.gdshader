shader_type canvas_item;
render_mode blend_disabled;

uniform float squares : hint_range(1.0, 128.0) = 16.0;
uniform vec4 colour_a : source_color = vec4(0.22, 0.22, 0.24, 1.0);
uniform vec4 colour_b : source_color = vec4(0.32, 0.32, 0.35, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform bool behind = true;
uniform vec2 tex_size;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 aspect = vec2(1.0, max(tex_size.y, 1.0) / max(tex_size.x, 1.0));
	vec2 g = floor(UV * max(squares, 1.0) / aspect);
	float odd = mod(g.x + g.y, 2.0);
	vec3 board = mix(colour_a.rgb, colour_b.rgb, odd);
	if (behind) {
		vec3 o = mix(board, rgb, a);
		float oa = max(a, strength);
		if (oa < 0.0001) {
			COLOR = vec4(0.0);
		} else {
			COLOR = vec4(clamp(mix(rgb, o, strength), 0.0, 1.0) * oa, oa);
		}
	} else {
		rgb = mix(rgb, board, strength);
		COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
	}
}
