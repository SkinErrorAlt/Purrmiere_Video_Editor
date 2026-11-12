shader_type canvas_item;
render_mode blend_disabled;

uniform float radius : hint_range(0.0, 100.0) = 4.0;
uniform int shape : hint_range(0, 1) = 0;
uniform bool by_brightness = false;
uniform int mode = 0;
uniform vec2 direction = vec2(1.0, 0.0);
uniform float px_scale = 1.0;

float luma(vec4 c) {
	return dot(c.rgb, vec3(0.2126, 0.7152, 0.0722)) + c.a * 0.0001;
}

void fragment() {
	ivec2 size = textureSize(TEXTURE, 0);
	ivec2 p = clamp(ivec2(floor(UV * vec2(size))), ivec2(0), size - 1);
	bool diag = abs(direction.x) > 0.5 && abs(direction.y) > 0.5;
	float r = radius * max(px_scale, 0.0001);
	if (shape == 1) {
		r *= diag ? 0.2929 : 0.4142;
	} else if (diag) {
		r = 0.0;
	}
	int n = clamp(int(round(r)), 0, 100);
	ivec2 dv = ivec2(int(sign(direction.x)), int(sign(direction.y)));
	vec4 best = texelFetch(TEXTURE, p, 0);
	float best_l = luma(best);
	for (int i = 1; i <= 100; i++) {
		if (i > n) {
			break;
		}
		for (int s = -1; s <= 1; s += 2) {
			ivec2 q = clamp(p + dv * (i * s), ivec2(0), size - 1);
			vec4 c = texelFetch(TEXTURE, q, 0);
			if (by_brightness) {
				float l = luma(c);
				if ((mode == 0 && l > best_l) || (mode == 1 && l < best_l)) {
					best = c;
					best_l = l;
				}
			} else {
				best = mode == 0 ? max(best, c) : min(best, c);
			}
		}
	}
	COLOR = best;
}
