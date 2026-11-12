shader_type canvas_item;
render_mode blend_disabled;

uniform float threshold : hint_range(0.0, 1.0) = 0.55;
uniform float upper : hint_range(0.0, 1.0) = 1.0;
uniform float reach : hint_range(0.0, 400.0) = 80.0;
uniform int taps : hint_range(2, 32) = 16;
uniform bool vertical_sort = false;
uniform int sort_by : hint_range(0, 2) = 0;
uniform bool reverse = false;
uniform int seed : hint_range(0, 9999) = 0;
uniform float px_scale = 1.0;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

vec3 colour_at(sampler2D t, ivec2 p) {
	vec4 c = texelFetch(t, p, 0);
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
}

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float sort_key(vec3 c) {
	if (sort_by == 1) {
		float mx = max(c.r, max(c.g, c.b));
		float mn = min(c.r, min(c.g, c.b));
		float d = mx - mn;
		if (d < 0.00001) {
			return 0.0;
		}
		float h = 0.0;
		if (mx == c.r) {
			h = mod((c.g - c.b) / d, 6.0);
		} else if (mx == c.g) {
			h = (c.b - c.r) / d + 2.0;
		} else {
			h = (c.r - c.g) / d + 4.0;
		}
		return h / 6.0;
	}
	if (sort_by == 2) {
		float mx2 = max(c.r, max(c.g, c.b));
		return mx2 > 0.00001 ? (mx2 - min(c.r, min(c.g, c.b))) / mx2 : 0.0;
	}
	return luma(c);
}

bool in_span(vec3 c) {
	float l = luma(c);
	return l > threshold && l <= max(upper, threshold);
}

void fragment() {
	ivec2 size = textureSize(TEXTURE, 0);
	ivec2 p = ivec2(floor(UV * vec2(size)));
	p = clamp(p, ivec2(0), size - 1);
	ivec2 step_v = vertical_sort ? ivec2(0, 1) : ivec2(1, 0);
	int along = vertical_sort ? p.y : p.x;
	int across = vertical_sort ? p.x : p.y;
	int len_line = vertical_sort ? size.y : size.x;
	int seg = clamp(int(round(reach * max(px_scale, 0.0001))), 2, 400);
	int offset = int(hash11(float(across) * 1.37 + float(seed) * 17.1) * float(seg));
	vec3 me = colour_at(TEXTURE, p);
	if (!in_span(me)) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		int seg_start = ((along + offset) / seg) * seg - offset;
		int s = along;
		for (int k = 1; k <= 400; k++) {
			int q = along - k;
			if (k >= seg || q < max(seg_start, 0)) {
				break;
			}
			if (!in_span(colour_at(TEXTURE, p - step_v * k))) {
				break;
			}
			s = q;
		}
		int e = along;
		for (int k2 = 1; k2 <= 400; k2++) {
			int q2 = along + k2;
			if (k2 >= seg || q2 >= min(seg_start + seg, len_line)) {
				break;
			}
			if (!in_span(colour_at(TEXTURE, p + step_v * k2))) {
				break;
			}
			e = q2;
		}
		float mine = sort_key(me);
		int rank = 0;
		for (int j = 0; j <= 400; j++) {
			int at = s + j;
			if (at > e) {
				break;
			}
			if (at == along) {
				continue;
			}
			ivec2 pj = vertical_sort ? ivec2(p.x, at) : ivec2(at, p.y);
			float kj = sort_key(colour_at(TEXTURE, pj));
			bool before = reverse ? (kj > mine || (kj == mine && at < along)) : (kj < mine || (kj == mine && at < along));
			if (before) {
				rank += 1;
			}
		}
		COLOR = vec4(float(rank % 256) / 255.0, float(rank / 256) / 255.0, 1.0, 1.0);
	}
}
