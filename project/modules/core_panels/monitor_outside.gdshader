shader_type canvas_item;

uniform vec4 frame_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform int mode = 0;
uniform float amount = 0.5;
uniform vec4 tint : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform bool reveal_only = false;
uniform int reveal_count = 0;
uniform vec2 reveal_pts[32];

bool in_quad(vec2 p, int q) {
	float side = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 a = reveal_pts[q * 4 + i];
		vec2 b = reveal_pts[q * 4 + (i + 1) % 4];
		float c = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x);
		if (abs(c) > 0.0000001) {
			if (side == 0.0) {
				side = sign(c);
			} else if (sign(c) != side) {
				return false;
			}
		}
	}
	return true;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool inside = UV.x >= frame_uv.x && UV.y >= frame_uv.y && UV.x <= frame_uv.z && UV.y <= frame_uv.w;
	if (!inside) {
		bool shown = !reveal_only;
		if (reveal_only) {
			for (int q = 0; q < 8; q++) {
				if (q >= reveal_count) {
					break;
				}
				if (in_quad(UV, q)) {
					shown = true;
				}
			}
		}
		if (!shown) {
			c = vec4(0.0);
		} else if (mode == 1) {
			c *= 1.0 - amount;
		} else if (mode == 2) {
			c.rgb *= 1.0 - amount;
		} else if (mode == 3) {
			c.rgb = mix(c.rgb, vec3(c.a), amount);
		} else if (mode == 4) {
			c.rgb = mix(c.rgb, tint.rgb * c.a, amount);
		}
	}
	COLOR = c;
}
