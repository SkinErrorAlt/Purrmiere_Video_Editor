shader_type canvas_item;
render_mode blend_disabled;

uniform float brush_size : hint_range(1.0, 20.0) = 6.0;
uniform float reach = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

vec4 pick(vec4 c, vec4 a, vec4 b) {
	vec4 da = a - c;
	vec4 db = b - c;
	return dot(da, da) < dot(db, db) ? a : b;
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float r = max(brush_size * reach * max(px_scale, 0.0001), 0.75);
	vec2 s = vec2(r * 0.5) / dims;
	vec4 c = texture(TEXTURE, UV);
	vec4 sum = c;
	for (int j = 0; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			if (j == 0 && i <= 0) {
				continue;
			}
			vec2 o = vec2(float(i), float(j)) * s;
			sum += pick(c, texture(TEXTURE, UV + o), texture(TEXTURE, UV - o));
		}
	}
	COLOR = sum / 13.0;
}
