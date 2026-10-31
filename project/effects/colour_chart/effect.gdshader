shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform int layout : hint_range(0, 2) = 0;
uniform float size : hint_range(0.15, 0.8) = 0.32;
uniform float gap : hint_range(0.0, 0.3) = 0.12;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

const vec3 PATCHES[24] = vec3[24](
	vec3(115.0, 82.0, 68.0), vec3(194.0, 150.0, 130.0), vec3(98.0, 122.0, 157.0), vec3(87.0, 108.0, 67.0), vec3(133.0, 128.0, 177.0), vec3(103.0, 189.0, 170.0),
	vec3(214.0, 126.0, 44.0), vec3(80.0, 91.0, 166.0), vec3(193.0, 90.0, 99.0), vec3(94.0, 60.0, 108.0), vec3(157.0, 188.0, 64.0), vec3(224.0, 163.0, 46.0),
	vec3(56.0, 61.0, 150.0), vec3(70.0, 148.0, 73.0), vec3(175.0, 54.0, 60.0), vec3(231.0, 199.0, 31.0), vec3(187.0, 86.0, 149.0), vec3(8.0, 133.0, 161.0),
	vec3(243.0, 243.0, 242.0), vec3(200.0, 200.0, 200.0), vec3(160.0, 160.0, 160.0), vec3(122.0, 122.0, 121.0), vec3(85.0, 85.0, 85.0), vec3(52.0, 52.0, 52.0)
);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 full = max(tex_size, vec2(1.0));
	vec2 p = UV * full;
	vec2 cols_rows = vec2(6.0, 4.0);
	vec4 box;
	if (layout == 2) {
		box = vec4(0.0, 0.0, full.x, full.y);
	} else if (layout == 1) {
		cols_rows = vec2(12.0, 2.0);
		float h = full.y * size * 0.5;
		box = vec4(0.0, full.y - h, full.x, h);
	} else {
		float w = full.x * size;
		float h = w * 4.0 / 6.0;
		float m = full.y * 0.04;
		box = vec4(full.x - w - m, full.y - h - m, w, h);
	}
	vec2 q = (p - box.xy) / box.zw;
	vec4 outc = c;
	if (q.x >= 0.0 && q.y >= 0.0 && q.x < 1.0 && q.y < 1.0) {
		vec2 g = q * cols_rows;
		vec2 cell = floor(g);
		vec2 f = g - cell;
		int index = int(cell.y) * int(cols_rows.x) + int(cell.x);
		float half_gap = gap * 0.5;
		bool inside = f.x > half_gap && f.x < 1.0 - half_gap && f.y > half_gap && f.y < 1.0 - half_gap;
		vec3 col = inside ? PATCHES[clamp(index, 0, 23)] / 255.0 : vec3(0.02);
		vec4 chart = vec4(col, 1.0);
		outc = mix(c, chart, opacity);
	}
	COLOR = outc;
}
