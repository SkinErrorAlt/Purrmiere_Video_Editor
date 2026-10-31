shader_type canvas_item;
render_mode blend_disabled;

uniform int channel : hint_range(0, 6) = 3;
uniform float checker : hint_range(2.0, 128.0) = 16.0;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	float v;
	if (channel == 6) {
		vec2 cell = floor(UV * tex_size / max(checker * max(px_scale, 0.0001), 0.5));
		float bg = mod(cell.x + cell.y, 2.0) < 1.0 ? 0.6 : 0.4;
		COLOR = vec4(c.rgb + vec3(bg) * (1.0 - c.a), 1.0);
	} else {
		if (channel == 0) { v = rgb.r; }
		else if (channel == 1) { v = rgb.g; }
		else if (channel == 2) { v = rgb.b; }
		else if (channel == 3) { v = c.a; }
		else if (channel == 4) { v = dot(rgb, vec3(0.2126, 0.7152, 0.0722)); }
		else { float mx = max(rgb.r, max(rgb.g, rgb.b)); v = mx > 0.0001 ? (mx - min(rgb.r, min(rgb.g, rgb.b))) / mx : 0.0; }
		COLOR = vec4(vec3(clamp(v, 0.0, 1.0)), 1.0);
	}
}
