shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float columns : hint_range(1.0, 400.0) = 60.0;
uniform float rows : hint_range(1.0, 400.0) = 34.0;
uniform bool sharp = true;

void fragment() {
	vec2 cells = vec2(max(columns, 1.0), max(rows, 1.0));
	vec2 cell_uv = 1.0 / cells;
	vec2 base = floor(UV * cells) * cell_uv;
	vec4 sum = vec4(0.0);
	for (int y = 0; y < 4; y++) {
		for (int x = 0; x < 4; x++) {
			vec2 o = (vec2(float(x), float(y)) + 0.5) * 0.25;
			sum += texture(TEXTURE, base + o * cell_uv);
		}
	}
	vec4 avg = sum / 16.0;
	if (sharp) {
		COLOR = avg;
	} else {
		COLOR = mix(avg, texture(TEXTURE, UV), 0.3);
	}
}
