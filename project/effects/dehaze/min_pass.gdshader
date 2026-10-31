shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float radius : hint_range(1.0, 40.0) = 10.0;
uniform vec4 haze_colour : source_color = vec4(0.85, 0.87, 0.9, 1.0);
uniform vec2 direction = vec2(1.0, 0.0);
uniform bool from_picture = true;

float dark_of(vec4 c) {
	if (!from_picture) {
		return c.r;
	}
	if (c.a <= 0.0001) {
		return 1.0;
	}
	vec3 n = (c.rgb / c.a) / max(haze_colour.rgb, vec3(0.05));
	return clamp(min(n.r, min(n.g, n.b)), 0.0, 1.0);
}

void fragment() {
	float r = max(radius * px_scale, 0.0);
	int n = int(min(ceil(r), 32.0));
	float stride = n > 0 ? r / float(n) : 0.0;
	vec2 px = direction / max(tex_size, vec2(1.0));
	float m = dark_of(texture(TEXTURE, UV));
	for (int k = 1; k <= 32; k++) {
		if (k > n) {
			break;
		}
		float off = float(k) * stride;
		m = min(m, dark_of(texture(TEXTURE, clamp(UV + px * off, vec2(0.0), vec2(1.0)))));
		m = min(m, dark_of(texture(TEXTURE, clamp(UV - px * off, vec2(0.0), vec2(1.0)))));
	}
	COLOR = vec4(vec3(m), 1.0);
}
