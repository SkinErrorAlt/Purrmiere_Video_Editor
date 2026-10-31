shader_type canvas_item;
render_mode blend_disabled;

uniform int count : hint_range(1, 99) = 10;
uniform float offset : hint_range(0.0, 99.0) = 10.0;
uniform int fill = 0;
uniform vec4 fill_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float cell = min(dims.x, dims.y) / float(max(count, 1));
	float sf = float(seed);
	vec2 so = vec2(mod(sf * 12.9898, 997.0), mod(sf * 78.233, 991.0));
	vec2 p = UV * dims / cell;
	vec2 base = floor(p);
	float amt = clamp(offset, 0.0, 99.0) / 100.0;
	float best = -1.0;
	vec2 src = UV;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 id = base + vec2(float(x), float(y));
			vec2 off = (hash22(id + so) * 2.0 - 1.0) * amt;
			vec2 l = p - id - off;
			if (l.x >= 0.0 && l.x < 1.0 && l.y >= 0.0 && l.y < 1.0) {
				float order = (id.y + 64.0) * 4096.0 + id.x + 64.0;
				if (order > best) {
					best = order;
					src = (p - off) * cell / dims;
				}
			}
		}
	}
	vec4 c = texture(TEXTURE, UV);
	if (best >= 0.0) {
		COLOR = texture(TEXTURE, clamp(src, vec2(0.0), vec2(1.0)));
	} else if (fill == 0) {
		COLOR = vec4(fill_colour.rgb * fill_colour.a, fill_colour.a);
	} else if (fill == 1) {
		COLOR = vec4(max(c.a - c.rgb, vec3(0.0)), c.a);
	} else if (fill == 2) {
		COLOR = c;
	} else {
		COLOR = vec4(0.0);
	}
}
