shader_type canvas_item;
render_mode blend_disabled;

uniform float reach : hint_range(0.0, 400.0) = 80.0;
uniform bool vertical_sort = false;
uniform int seed : hint_range(0, 9999) = 0;
uniform float px_scale = 1.0;
uniform sampler2D effect_tex : filter_nearest, repeat_disable;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

bool spanned(sampler2D t, ivec2 p) {
	return texelFetch(t, p, 0).b > 0.5;
}

int rank_at(sampler2D t, ivec2 p) {
	vec4 r = texelFetch(t, p, 0);
	return int(round(r.r * 255.0)) + int(round(r.g * 255.0)) * 256;
}

void fragment() {
	ivec2 size = textureSize(TEXTURE, 0);
	ivec2 p = clamp(ivec2(floor(UV * vec2(size))), ivec2(0), size - 1);
	vec4 orig = texelFetch(effect_tex, p, 0);
	if (!spanned(TEXTURE, p)) {
		COLOR = orig;
	} else {
		ivec2 step_v = vertical_sort ? ivec2(0, 1) : ivec2(1, 0);
		int along = vertical_sort ? p.y : p.x;
		int across = vertical_sort ? p.x : p.y;
		int seg = clamp(int(round(reach * max(px_scale, 0.0001))), 2, 400);
		int offset = int(hash11(float(across) * 1.37 + float(seed) * 17.1) * float(seg));
		int seg_start = ((along + offset) / seg) * seg - offset;
		int s = along;
		for (int k = 1; k <= 400; k++) {
			int q = along - k;
			if (k >= seg || q < max(seg_start, 0)) {
				break;
			}
			if (!spanned(TEXTURE, p - step_v * k)) {
				break;
			}
			s = q;
		}
		int want = along - s;
		vec4 found = orig;
		for (int j = 0; j <= 400; j++) {
			int at = s + j;
			ivec2 pj = vertical_sort ? ivec2(p.x, at) : ivec2(at, p.y);
			if (j >= seg || at >= (vertical_sort ? size.y : size.x) || !spanned(TEXTURE, pj)) {
				break;
			}
			if (rank_at(TEXTURE, pj) == want) {
				found = texelFetch(effect_tex, pj, 0);
				break;
			}
		}
		COLOR = found;
	}
}
