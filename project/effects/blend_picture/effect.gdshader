shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D picture : filter_linear, repeat_enable, hint_default_transparent;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform int mode : hint_range(0, 23) = 9;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform int fit : hint_range(0, 3) = 0;
uniform float scale : hint_range(0.05, 10.0) = 1.0;
uniform vec2 position = vec2(0.5, 0.5);
uniform int order : hint_range(0, 1) = 0;
uniform bool keep_alpha = true;

float lum(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

vec3 clip_colour(vec3 c) {
	float l = lum(c);
	float n = min(c.r, min(c.g, c.b));
	float x = max(c.r, max(c.g, c.b));
	if (n < 0.0) {
		c = l + (c - l) * l / max(l - n, 0.00001);
	}
	if (x > 1.0) {
		c = l + (c - l) * (1.0 - l) / max(x - l, 0.00001);
	}
	return c;
}

vec3 set_lum(vec3 c, float l) {
	return clip_colour(c + (l - lum(c)));
}

float sat(vec3 c) {
	return max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
}

vec3 set_sat(vec3 c, float s) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	if (mx - mn < 0.00001) {
		return vec3(0.0);
	}
	return (c - mn) * s / (mx - mn);
}

float burn(float b, float s) {
	if (b >= 1.0) {
		return 1.0;
	}
	if (s <= 0.0) {
		return 0.0;
	}
	return 1.0 - min(1.0, (1.0 - b) / s);
}

float dodge(float b, float s) {
	if (b <= 0.0) {
		return 0.0;
	}
	if (s >= 1.0) {
		return 1.0;
	}
	return min(1.0, b / (1.0 - s));
}

float soft(float b, float s) {
	if (s <= 0.5) {
		return b - (1.0 - 2.0 * s) * b * (1.0 - b);
	}
	float d = b <= 0.25 ? ((16.0 * b - 12.0) * b + 4.0) * b : sqrt(b);
	return b + (2.0 * s - 1.0) * (d - b);
}

float hard(float b, float s) {
	return s <= 0.5 ? b * 2.0 * s : 1.0 - (1.0 - b) * (1.0 - (2.0 * s - 1.0));
}

float vivid(float b, float s) {
	return s <= 0.5 ? burn(b, 2.0 * s) : dodge(b, 2.0 * s - 1.0);
}

float pin(float b, float s) {
	return s <= 0.5 ? min(b, 2.0 * s) : max(b, 2.0 * s - 1.0);
}

vec3 per_channel(vec3 b, vec3 s, int m) {
	vec3 o = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		float x = b[i];
		float y = s[i];
		float r = y;
		if (m == 1) {
			r = min(x, y);
		} else if (m == 2) {
			r = x * y;
		} else if (m == 3) {
			r = burn(x, y);
		} else if (m == 4) {
			r = x + y - 1.0;
		} else if (m == 5) {
			r = max(x, y);
		} else if (m == 6) {
			r = x + y - x * y;
		} else if (m == 7) {
			r = dodge(x, y);
		} else if (m == 8) {
			r = x + y;
		} else if (m == 9) {
			r = hard(y, x);
		} else if (m == 10) {
			r = soft(x, y);
		} else if (m == 11) {
			r = hard(x, y);
		} else if (m == 12) {
			r = vivid(x, y);
		} else if (m == 13) {
			r = x + 2.0 * y - 1.0;
		} else if (m == 14) {
			r = pin(x, y);
		} else if (m == 15) {
			r = vivid(x, y) < 0.5 ? 0.0 : 1.0;
		} else if (m == 16) {
			r = abs(x - y);
		} else if (m == 17) {
			r = x + y - 2.0 * x * y;
		} else if (m == 18) {
			r = x - y;
		} else if (m == 19) {
			r = y <= 0.0 ? 1.0 : x / y;
		}
		o[i] = r;
	}
	return clamp(o, 0.0, 1.0);
}

vec3 blend_of(vec3 b, vec3 s, int m) {
	if (m == 20) {
		return set_lum(set_sat(s, sat(b)), lum(b));
	}
	if (m == 21) {
		return set_lum(set_sat(b, sat(s)), lum(b));
	}
	if (m == 22) {
		return set_lum(s, lum(b));
	}
	if (m == 23) {
		return set_lum(b, lum(s));
	}
	return per_channel(b, s, m);
}

vec4 picture_at(vec2 uv) {
	vec2 pic = vec2(textureSize(picture, 0));
	vec2 frame = max(tex_size, vec2(1.0));
	float pa = pic.x / max(pic.y, 1.0);
	float fa = frame.x / frame.y;
	vec2 q = (uv - position) / max(scale, 0.01);
	if (fit == 0) {
		if (pa > fa) {
			q.x *= fa / pa;
		} else {
			q.y *= pa / fa;
		}
	} else if (fit == 1 || fit == 3) {
		if (pa > fa) {
			q.y *= pa / fa;
		} else {
			q.x *= fa / pa;
		}
	}
	vec2 p = q + 0.5;
	if (fit == 3) {
		p = fract(p);
	} else if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) {
		return vec4(0.0);
	}
	return texture(picture, p);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 clip_rgb = c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
	vec4 p = picture_at(UV);
	float pa = clamp(p.a, 0.0, 1.0);
	vec3 pic_rgb = clamp(p.rgb, 0.0, 1.0);
	vec4 o = c;
	if (order == 0) {
		float w = pa * clamp(opacity, 0.0, 1.0);
		vec3 mixed = mix(clip_rgb, blend_of(clip_rgb, pic_rgb, mode), w);
		if (keep_alpha) {
			o = vec4(mixed * c.a, c.a);
		} else {
			o = vec4(mixed * c.a + pic_rgb * w * (1.0 - c.a), c.a + w * (1.0 - c.a));
		}
	} else {
		float w = c.a * clamp(opacity, 0.0, 1.0);
		vec3 mixed = mix(pic_rgb, blend_of(pic_rgb, clip_rgb, mode), w);
		if (keep_alpha) {
			vec3 rgb = mix(clip_rgb, mixed, pa);
			o = vec4(rgb * c.a, c.a);
		} else {
			o = vec4(mixed * pa + clip_rgb * w * (1.0 - pa), pa + w * (1.0 - pa));
		}
	}
	COLOR = clamp(o, 0.0, 1.0);
}
