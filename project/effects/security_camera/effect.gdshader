shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform int camera_number : hint_range(1, 99) = 1;
uniform int day : hint_range(1, 31) = 25;
uniform int month : hint_range(1, 12) = 9;
uniform int year : hint_range(2000, 2099) = 2026;
uniform int start_hour : hint_range(0, 23) = 23;
uniform int start_minute : hint_range(0, 59) = 41;
uniform bool show_text = true;
uniform float text_size : hint_range(0.5, 2.0) = 1.0;
uniform float black_white : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint : source_color = vec4(0.86, 1.0, 0.9, 1.0);
uniform float low_res : hint_range(0.0, 1.0) = 0.5;
uniform float noise : hint_range(0.0, 1.0) = 0.4;
uniform float lines : hint_range(0.0, 1.0) = 0.25;
uniform float vignette : hint_range(0.0, 1.0) = 0.5;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

ivec2 glyph_bits(int g) {
	if (g == 0) {
		return ivec2(708142, 14905);
	} else if (g == 1) {
		return ivec2(135556, 14468);
	} else if (g == 2) {
		return ivec2(67118, 32004);
	} else if (g == 3) {
		return ivec2(69727, 14881);
	} else if (g == 4) {
		return ivec2(600258, 2143);
	} else if (g == 5) {
		return ivec2(64031, 14881);
	} else if (g == 6) {
		return ivec2(999686, 14897);
	} else if (g == 7) {
		return ivec2(133183, 8456);
	} else if (g == 8) {
		return ivec2(476718, 14897);
	} else if (g == 9) {
		return ivec2(509486, 12353);
	} else if (g == 10) {
		return ivec2(12672, 396);
	} else if (g == 11) {
		return ivec2(133153, 16904);
	} else if (g == 12) {
		return ivec2(0, 0);
	} else if (g == 13) {
		return ivec2(1033774, 17969);
	} else if (g == 14) {
		return ivec2(1001022, 31281);
	} else if (g == 15) {
		return ivec2(541230, 14896);
	} else if (g == 16) {
		return ivec2(575068, 29265);
	} else if (g == 17) {
		return ivec2(999967, 32272);
	} else if (g == 18) {
		return ivec2(135310, 14468);
	} else if (g == 19) {
		return ivec2(710513, 17969);
	} else if (g == 20) {
		return ivec2(714289, 17971);
	} else if (g == 21) {
		return ivec2(575022, 14897);
	} else if (g == 22) {
		return ivec2(1001022, 16912);
	} else if (g == 23) {
		return ivec2(1001022, 18004);
	} else if (g == 24) {
		return ivec2(135327, 4228);
	} else if (g == 25) {
		return ivec2(575025, 14897);
	} else if (g == 26) {
		return ivec2(141873, 4228);
	} else if (g == 27) {
		return ivec2(541200, 32272);
	} else if (g == 28) {
		return ivec2(475663, 30753);
	}
	return ivec2(0, 0);
}

float glyph_on(int g, vec2 cell) {
	if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= 5.0 || cell.y >= 7.0) {
		return 0.0;
	}
	ivec2 bits = glyph_bits(g);
	int cx = int(cell.x);
	int cy = int(cell.y);
	int row = cy < 4 ? (bits.x >> (5 * cy)) & 31 : (bits.y >> (5 * (cy - 4))) & 31;
	return float((row >> (4 - cx)) & 1);
}

int two_digits(int v, int i) {
	int n = clamp(v, 0, 99);
	return i == 0 ? n / 10 : n % 10;
}

int stamp_char(int i) {
	int total = start_hour * 3600 + start_minute * 60 + int(floor(max(clip_time, 0.0)));
	int extra_days = total / 86400;
	total = total % 86400;
	int h = total / 3600;
	int m = (total / 60) % 60;
	int s = total % 60;
	int d = clamp(day, 1, 31) + extra_days;
	if (i == 0 || i == 1) {
		return two_digits(d, i);
	}
	if (i == 2 || i == 5) {
		return 11;
	}
	if (i == 3 || i == 4) {
		return two_digits(month, i - 3);
	}
	if (i >= 6 && i <= 9) {
		int y = clamp(year, 0, 9999);
		if (i == 6) {
			return (y / 1000) % 10;
		}
		if (i == 7) {
			return (y / 100) % 10;
		}
		if (i == 8) {
			return (y / 10) % 10;
		}
		return y % 10;
	}
	if (i == 10 || i == 11) {
		return 12;
	}
	if (i == 14 || i == 17) {
		return 10;
	}
	if (i == 12 || i == 13) {
		return two_digits(h, i - 12);
	}
	if (i == 15 || i == 16) {
		return two_digits(m, i - 15);
	}
	return two_digits(s, i - 18);
}

int char_code(int which, int i) {
	if (which == 0) {
		return stamp_char(i);
	}
	if (i == 0) {
		return 15;
	}
	if (i == 1) {
		return 13;
	}
	if (i == 2) {
		return 19;
	}
	if (i == 3) {
		return 12;
	}
	return two_digits(camera_number, i - 4);
}

int line_length(int which) {
	return which == 0 ? 20 : 6;
}

float text_cover(vec2 p, vec2 origin, float cell, int which) {
	float acc = 0.0;
	for (int k = 0; k < 4; k++) {
		vec2 o = (vec2(float(k % 2), float(k / 2)) - 0.5) * 0.5;
		vec2 q = (p + o - origin) / cell;
		if (q.x >= 0.0 && q.y >= 0.0 && q.y < 7.0) {
			int i = int(floor(q.x / 6.0));
			if (i < line_length(which)) {
				acc += glyph_on(char_code(which, i), vec2(q.x - float(i) * 6.0, q.y));
			}
		}
	}
	return acc * 0.25;
}

float labels(vec2 p, vec2 frame) {
	if (!show_text) {
		return 0.0;
	}
	float cell = 0.0055 * frame.y * clamp(text_size, 0.5, 2.0);
	float m = 0.05 * frame.y;
	float t = text_cover(p, vec2(m, m), cell, 0);
	t = max(t, text_cover(p, vec2(m, frame.y - m - 7.0 * cell), cell, 1));
	return t;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec4 soft_tap(sampler2D tex, vec2 uv, vec2 texel) {
	vec4 s = texture(tex, clamp(uv + texel * vec2(-0.5, -0.5), vec2(0.0), vec2(1.0)));
	s += texture(tex, clamp(uv + texel * vec2(0.5, -0.5), vec2(0.0), vec2(1.0)));
	s += texture(tex, clamp(uv + texel * vec2(-0.5, 0.5), vec2(0.0), vec2(1.0)));
	s += texture(tex, clamp(uv + texel * vec2(0.5, 0.5), vec2(0.0), vec2(1.0)));
	return s * 0.25;
}

void fragment() {
	vec2 frame = max(tex_size, vec2(1.0));
	vec2 p = UV * frame;
	float lr = clamp(low_res, 0.0, 1.0);
	vec4 c;
	if (lr > 0.001) {
		float rows = mix(frame.y, 200.0, lr);
		vec2 grid = vec2(rows * frame.x / frame.y, rows);
		vec2 g = UV * grid - 0.5;
		vec2 f = fract(g);
		vec2 b = floor(g);
		vec2 texel = 1.0 / grid;
		vec4 c00 = soft_tap(TEXTURE, (b + vec2(0.5, 0.5)) / grid, texel);
		vec4 c10 = soft_tap(TEXTURE, (b + vec2(1.5, 0.5)) / grid, texel);
		vec4 c01 = soft_tap(TEXTURE, (b + vec2(0.5, 1.5)) / grid, texel);
		vec4 c11 = soft_tap(TEXTURE, (b + vec2(1.5, 1.5)) / grid, texel);
		c = mix(mix(c00, c10, f.x), mix(c01, c11, f.x), f.y);
	} else {
		c = texture(TEXTURE, UV);
	}
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float l = dot(rgb, LUMA);
	vec3 mono = vec3(l) * tint.rgb / max(dot(tint.rgb, LUMA), 0.2);
	rgb = mix(rgb, mono, clamp(black_white, 0.0, 1.0));
	rgb = (rgb - 0.5) * 1.12 + 0.5;
	rgb = mix(vec3(0.04), vec3(0.96), clamp(rgb, 0.0, 1.0));
	float frame_no = floor(clip_time * 15.0);
	float cell_px = max(1.5 * max(px_scale, 0.0001), 1.0);
	float grain = hash12(floor(p / cell_px) + vec2(frame_no * 37.0, frame_no * 11.0)) - 0.5;
	rgb += grain * 0.22 * clamp(noise, 0.0, 1.0);
	float band = hash12(vec2(floor(UV.y * 90.0), frame_no));
	rgb += step(0.985, band) * 0.12 * clamp(noise, 0.0, 1.0);
	float scan = 0.5 + 0.5 * cos(UV.y * 3.14159265 * 240.0);
	rgb *= 1.0 - clamp(lines, 0.0, 1.0) * 0.35 * scan;
	vec2 d = (UV - 0.5) * vec2(frame.x / frame.y, 1.0);
	rgb *= 1.0 - clamp(vignette, 0.0, 1.0) * smoothstep(0.35, 1.0, length(d) * 1.1);
	rgb = clamp(rgb, 0.0, 1.0);
	vec3 col = rgb * a;
	float shadow = labels(p - vec2(0.0012 * frame.y), frame) * 0.6;
	col *= 1.0 - shadow;
	float alpha = max(a, shadow);
	float txt = labels(p, frame);
	col = mix(col, vec3(0.97), txt);
	alpha = max(alpha, txt);
	COLOR = vec4(clamp(col, vec3(0.0), vec3(alpha)), alpha);
}
