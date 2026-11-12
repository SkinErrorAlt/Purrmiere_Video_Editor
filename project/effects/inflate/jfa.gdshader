shader_type canvas_item;
render_mode blend_disabled;

uniform float jump = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);

vec2 unpack2(vec4 c) {
	return vec2(floor(c.r * 255.0 + 0.5) * 256.0 + floor(c.g * 255.0 + 0.5), floor(c.b * 255.0 + 0.5) * 256.0 + floor(c.a * 255.0 + 0.5));
}

vec4 pack2(vec2 v) {
	vec2 hi = floor(v / 256.0);
	vec2 lo = v - hi * 256.0;
	return vec4(hi.x / 255.0, lo.x / 255.0, hi.y / 255.0, lo.y / 255.0);
}

void fragment() {
	ivec2 size = ivec2(max(tex_size, vec2(1.0)));
	ivec2 me = ivec2(floor(UV * tex_size));
	vec2 best = vec2(65535.0);
	float bd = 1e20;
	int j = int(jump);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			ivec2 at = me + ivec2(x, y) * j;
			if (at.x < 0 || at.y < 0 || at.x >= size.x || at.y >= size.y) {
				continue;
			}
			vec2 s = unpack2(texelFetch(TEXTURE, at, 0));
			if (s.x > 65000.0) {
				continue;
			}
			vec2 dv = s - vec2(me);
			float dd = dot(dv, dv);
			if (dd < bd) {
				bd = dd;
				best = s;
			}
		}
	}
	COLOR = best.x > 65000.0 ? vec4(1.0) : pack2(best);
}
