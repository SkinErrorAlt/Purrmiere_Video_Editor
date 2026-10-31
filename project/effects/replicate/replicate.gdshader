shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int count : hint_range(1, 16) = 3;
uniform bool mirror = false;
uniform float gap : hint_range(0.0, 100.0) = 0.0;
uniform vec4 gap_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float n = float(clamp(count, 1, 16));
	vec2 p = UV * n;
	vec2 cell = min(floor(p), vec2(n - 1.0));
	vec2 f = p - cell;
	vec2 cell_px = size / n;
	vec2 inset = min(vec2(gap * px_scale * 0.5), cell_px * 0.45) / cell_px;
	vec2 q = (f - inset) / max(vec2(1.0) - 2.0 * inset, vec2(0.0001));
	bool inside = q.x >= 0.0 && q.x <= 1.0 && q.y >= 0.0 && q.y <= 1.0;
	if (mirror) {
		if (mod(cell.x, 2.0) >= 1.0) {
			q.x = 1.0 - q.x;
		}
		if (mod(cell.y, 2.0) >= 1.0) {
			q.y = 1.0 - q.y;
		}
	}
	if (inside) {
		COLOR = texture(TEXTURE, clamp(q, vec2(0.0), vec2(1.0)));
	} else {
		COLOR = vec4(gap_colour.rgb * gap_colour.a, gap_colour.a);
	}
}
