shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int view : hint_range(0, 3) = 0;
uniform vec4 colour : source_color = vec4(1.0, 0.0, 1.0, 1.0);
uniform float squares : hint_range(4.0, 200.0) = 16.0;
uniform float threshold : hint_range(0.0, 0.2) = 0.02;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = clamp(c.a, 0.0, 1.0);
	vec2 px = UV * max(tex_size, vec2(1.0)) / max(squares * max(px_scale, 0.0001), 1.0);
	float board = mod(floor(px.x) + floor(px.y), 2.0) < 1.0 ? 0.42 : 0.62;
	vec3 o = vec3(0.0);
	if (view == 0) {
		o = c.rgb + vec3(board) * (1.0 - a);
	} else if (view == 1) {
		o = c.rgb + colour.rgb * (1.0 - a);
	} else if (view == 2) {
		o = vec3(a);
	} else {
		float part = (a > threshold + 0.001 && a < 1.0 - threshold - 0.001) ? 1.0 : 0.0;
		o = mix(vec3(a), colour.rgb, part * 0.85);
	}
	COLOR = vec4(clamp(o, 0.0, 1.0), 1.0);
}
