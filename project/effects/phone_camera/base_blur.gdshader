shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float halo : hint_range(8.0, 160.0) = 56.0;
uniform vec2 direction = vec2(1.0, 0.0);

void fragment() {
	vec2 px = direction / tex_size;
	float r = max(halo * px_scale, 0.5);
	float sigma = r * 0.5;
	float spacing = max(r / 6.0, 0.5);
	float sum = 0.0;
	float ws = 0.0;
	for (int i = -6; i <= 6; i++) {
		float o = float(i) * spacing;
		float w = exp(-o * o / (2.0 * sigma * sigma));
		sum += texture(TEXTURE, UV + px * o).r * w;
		ws += w;
	}
	float v = sum / ws;
	COLOR = vec4(v, v, v, 1.0);
}
