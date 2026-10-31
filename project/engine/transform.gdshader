shader_type canvas_item;
render_mode blend_premul_alpha;

uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform int blend = 0;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

float dodge_ch(float d, float s) {
	if (d <= 0.0) {
		return 0.0;
	}
	if (s >= 1.0) {
		return 1.0;
	}
	return min(1.0, d / (1.0 - s));
}

float burn_ch(float d, float s) {
	if (d >= 1.0) {
		return 1.0;
	}
	if (s <= 0.0) {
		return 0.0;
	}
	return 1.0 - min(1.0, (1.0 - d) / s);
}

float soft_ch(float d, float s) {
	if (s <= 0.5) {
		return d - (1.0 - 2.0 * s) * d * (1.0 - d);
	}
	float dd = d <= 0.25 ? ((16.0 * d - 12.0) * d + 4.0) * d : sqrt(d);
	return d + (2.0 * s - 1.0) * (dd - d);
}

float hard_ch(float d, float s) {
	if (s <= 0.5) {
		return d * 2.0 * s;
	}
	float s2 = 2.0 * s - 1.0;
	return d + s2 - d * s2;
}

float vivid_ch(float d, float s) {
	if (s <= 0.5) {
		return burn_ch(d, 2.0 * s);
	}
	return dodge_ch(d, 2.0 * (s - 0.5));
}

float pin_ch(float d, float s) {
	if (s <= 0.5) {
		return min(d, 2.0 * s);
	}
	return max(d, 2.0 * s - 1.0);
}

float divide_ch(float d, float s) {
	if (s <= 0.0) {
		return d > 0.0 ? 1.0 : 0.0;
	}
	return min(d / s, 1.0);
}

float lum(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

vec3 clip_colour(vec3 c) {
	float l = lum(c);
	float n = min(min(c.r, c.g), c.b);
	float x = max(max(c.r, c.g), c.b);
	if (n < 0.0) {
		c = vec3(l) + (c - vec3(l)) * l / max(l - n, 0.000001);
	}
	if (x > 1.0) {
		c = vec3(l) + (c - vec3(l)) * (1.0 - l) / max(x - l, 0.000001);
	}
	return c;
}

vec3 set_lum(vec3 c, float l) {
	return clip_colour(c + vec3(l - lum(c)));
}

float sat_of(vec3 c) {
	return max(max(c.r, c.g), c.b) - min(min(c.r, c.g), c.b);
}

vec3 set_sat(vec3 c, float s) {
	float hi = max(max(c.r, c.g), c.b);
	float lo = min(min(c.r, c.g), c.b);
	float span = hi - lo;
	if (span <= 0.000001) {
		return vec3(0.0);
	}
	return (c - vec3(lo)) * s / span;
}

vec3 blend_pair(vec3 d, vec3 s, int mode) {
	if (mode == 2) {
		return d * s;
	}
	if (mode == 3) {
		return 1.0 - (1.0 - d) * (1.0 - s);
	}
	if (mode == 4) {
		vec3 lo = 2.0 * d * s;
		vec3 hi = 1.0 - 2.0 * (1.0 - d) * (1.0 - s);
		return mix(lo, hi, step(0.5, d));
	}
	if (mode == 5) {
		return min(d, s);
	}
	if (mode == 6) {
		return max(d, s);
	}
	if (mode == 7) {
		return abs(d - s);
	}
	if (mode == 8) {
		return max(d - s, vec3(0.0));
	}
	if (mode == 9) {
		return vec3(soft_ch(d.r, s.r), soft_ch(d.g, s.g), soft_ch(d.b, s.b));
	}
	if (mode == 10) {
		return vec3(hard_ch(d.r, s.r), hard_ch(d.g, s.g), hard_ch(d.b, s.b));
	}
	if (mode == 11) {
		return vec3(dodge_ch(d.r, s.r), dodge_ch(d.g, s.g), dodge_ch(d.b, s.b));
	}
	if (mode == 12) {
		return vec3(burn_ch(d.r, s.r), burn_ch(d.g, s.g), burn_ch(d.b, s.b));
	}
	if (mode == 13) {
		return max(d + s - 1.0, vec3(0.0));
	}
	if (mode == 14) {
		return clamp(d + 2.0 * s - 1.0, vec3(0.0), vec3(1.0));
	}
	if (mode == 15) {
		return vec3(vivid_ch(d.r, s.r), vivid_ch(d.g, s.g), vivid_ch(d.b, s.b));
	}
	if (mode == 16) {
		return vec3(pin_ch(d.r, s.r), pin_ch(d.g, s.g), pin_ch(d.b, s.b));
	}
	if (mode == 17) {
		return d + s - 2.0 * d * s;
	}
	if (mode == 18) {
		return vec3(divide_ch(d.r, s.r), divide_ch(d.g, s.g), divide_ch(d.b, s.b));
	}
	if (mode == 19) {
		return set_lum(set_sat(s, sat_of(d)), lum(d));
	}
	if (mode == 20) {
		return set_lum(set_sat(d, sat_of(s)), lum(d));
	}
	if (mode == 21) {
		return set_lum(s, lum(d));
	}
	if (mode == 22) {
		return set_lum(d, lum(s));
	}
	return s;
}

void fragment() {
	vec4 s = texture(TEXTURE, UV) * opacity;
	if (blend == 0) {
		COLOR = s;
	} else {
		vec4 d = texture(screen_tex, SCREEN_UV);
		if (blend == 1) {
			COLOR = vec4(s.rgb + d.rgb * s.a, s.a);
		} else {
			vec3 sc = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
			vec3 dc = d.a > 0.0001 ? d.rgb / d.a : vec3(0.0);
			vec3 b = clamp(blend_pair(dc, sc, blend), vec3(0.0), vec3(1.0));
			vec3 r = mix(sc, b, d.a);
			COLOR = vec4(r * s.a, s.a);
		}
	}
}
