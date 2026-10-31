shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform bool rec = true;
uniform bool counter = true;
uniform float counter_start : hint_range(0.0, 86399.0) = 0.0;
uniform bool battery = true;
uniform bool corners = true;
uniform bool centre_cross = false;
uniform vec4 overlay_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float size : hint_range(0.5, 2.0) = 1.0;
uniform float margin : hint_range(0.02, 0.2) = 0.07;
uniform float blink : hint_range(0.0, 4.0) = 1.0;
uniform float video_look : hint_range(0.0, 1.0) = 0.35;

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

int counter_char(int i) {
	int total = int(floor(max(counter_start + clip_time, 0.0)));
	int h = (total / 3600) % 100;
	int m = (total / 60) % 60;
	int s = total % 60;
	if (i == 2 || i == 5) {
		return 10;
	}
	if (i == 0) {
		return h / 10;
	}
	if (i == 1) {
		return h % 10;
	}
	if (i == 3) {
		return m / 10;
	}
	if (i == 4) {
		return m % 10;
	}
	if (i == 6) {
		return s / 10;
	}
	return s % 10;
}

int char_code(int which, int i) {
	if (which == 0) {
		if (i == 0) {
			return 23;
		}
		if (i == 1) {
			return 17;
		}
		return 15;
	}
	return counter_char(i);
}

int line_length(int which) {
	return which == 0 ? 3 : 8;
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

float box_cover(vec2 p, vec2 lo, vec2 hi) {
	vec2 d = min(p - lo, hi - p);
	return clamp(min(d.x, d.y) + 0.5, 0.0, 1.0);
}

float disc_cover(vec2 p, vec2 c, float r) {
	return clamp(r - length(p - c) + 0.5, 0.0, 1.0);
}

float corner_marks(vec2 p, vec2 lo, vec2 hi, float arm, float th) {
	float m = 0.0;
	m = max(m, box_cover(p, lo, vec2(lo.x + arm, lo.y + th)));
	m = max(m, box_cover(p, lo, vec2(lo.x + th, lo.y + arm)));
	m = max(m, box_cover(p, vec2(hi.x - arm, lo.y), vec2(hi.x, lo.y + th)));
	m = max(m, box_cover(p, vec2(hi.x - th, lo.y), vec2(hi.x, lo.y + arm)));
	m = max(m, box_cover(p, vec2(lo.x, hi.y - th), vec2(lo.x + arm, hi.y)));
	m = max(m, box_cover(p, vec2(lo.x, hi.y - arm), vec2(lo.x + th, hi.y)));
	m = max(m, box_cover(p, vec2(hi.x - arm, hi.y - th), hi));
	m = max(m, box_cover(p, vec2(hi.x - th, hi.y - arm), hi));
	return m;
}

vec2 overlay(vec2 p, vec2 frame) {
	float h = frame.y;
	float s = clamp(size, 0.5, 2.0);
	float m = clamp(margin, 0.0, 0.25) * h;
	float th = max(0.004 * h * s, 1.0);
	float cell = 0.0065 * h * s;
	vec2 lo = vec2(m);
	vec2 hi = frame - vec2(m);
	float white = 0.0;
	float red = 0.0;
	if (corners) {
		white = max(white, corner_marks(p, lo, hi, 0.07 * h * s, th));
	}
	vec2 inner = lo + vec2(0.035 * h * s);
	vec2 inner_hi = hi - vec2(0.035 * h * s);
	if (rec) {
		float r = 0.017 * h * s;
		bool lit = blink <= 0.0 || fract(clip_time * blink) < 0.5;
		if (lit) {
			red = disc_cover(p, inner + vec2(r, 3.5 * cell), r);
		}
		white = max(white, text_cover(p, inner + vec2(2.0 * r + 2.0 * cell, 0.0), cell, 0));
	}
	if (counter) {
		float w = (8.0 * 6.0 - 1.0) * cell;
		white = max(white, text_cover(p, vec2(inner_hi.x - w, inner.y), cell, 1));
	}
	if (battery) {
		vec2 b_hi = inner_hi;
		vec2 b_lo = b_hi - vec2(0.07, 0.032) * h * s;
		float outline = clamp(box_cover(p, b_lo, b_hi) - box_cover(p, b_lo + vec2(th), b_hi - vec2(th)), 0.0, 1.0);
		float nub = box_cover(p, vec2(b_lo.x - 0.006 * h * s, mix(b_lo.y, b_hi.y, 0.3)), vec2(b_lo.x, mix(b_lo.y, b_hi.y, 0.7)));
		float bars = 0.0;
		vec2 in_lo = b_lo + vec2(2.0 * th);
		vec2 in_hi = b_hi - vec2(2.0 * th);
		float bw = (in_hi.x - in_lo.x) / 3.0;
		for (int i = 0; i < 3; i++) {
			float x0 = in_lo.x + float(i) * bw;
			bars = max(bars, box_cover(p, vec2(x0 + th * 0.5, in_lo.y), vec2(x0 + bw - th * 0.5, in_hi.y)));
		}
		white = max(white, max(outline, max(nub, bars)));
	}
	if (centre_cross) {
		vec2 c = frame * 0.5;
		float arm = 0.03 * h * s;
		white = max(white, box_cover(p, c - vec2(arm, th * 0.5), c + vec2(arm, th * 0.5)));
		white = max(white, box_cover(p, c - vec2(th * 0.5, arm), c + vec2(th * 0.5, arm)));
	}
	return vec2(white, red);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 frame = max(tex_size, vec2(1.0));
	vec2 p = UV * frame;
	vec4 c = texture(TEXTURE, UV);
	float look = clamp(video_look, 0.0, 1.0);
	if (look > 0.0) {
		vec2 px = vec2(1.2 * max(px_scale, 0.0001)) / frame;
		vec4 soft = texture(TEXTURE, UV + vec2(px.x, 0.0));
		soft += texture(TEXTURE, UV - vec2(px.x, 0.0));
		soft += texture(TEXTURE, UV + vec2(0.0, px.y));
		soft += texture(TEXTURE, UV - vec2(0.0, px.y));
		c = mix(c, soft * 0.25, 0.6 * look);
		float a0 = c.a;
		vec3 rgb = a0 > 0.0001 ? c.rgb / a0 : vec3(0.0);
		float l = dot(rgb, LUMA);
		rgb = mix(vec3(l), rgb, 1.0 - 0.3 * look);
		rgb *= vec3(1.0 + 0.04 * look, 1.0, 1.0 - 0.06 * look);
		rgb = mix(rgb, vec3(0.05) + rgb * 0.92, look);
		float grain = hash12(floor(p / max(px_scale, 0.0001)) + vec2(floor(clip_time * 30.0) * 17.0, 3.0)) - 0.5;
		rgb += grain * 0.05 * look;
		vec2 d = UV - 0.5;
		rgb *= 1.0 - 0.3 * look * dot(d, d) * 2.0;
		c = vec4(clamp(rgb, 0.0, 1.0) * a0, a0);
	}
	vec2 shadow_off = vec2(0.0015 * frame.y * clamp(size, 0.5, 2.0));
	vec2 sh = overlay(p - shadow_off, frame);
	vec2 ov = overlay(p, frame);
	float shadow = max(sh.x, sh.y) * 0.45;
	vec3 col = c.rgb * (1.0 - shadow);
	float alpha = max(c.a, shadow);
	float wk = ov.x * overlay_colour.a;
	col = mix(col, overlay_colour.rgb, wk);
	alpha = max(alpha, wk);
	col = mix(col, vec3(0.95, 0.08, 0.06), ov.y);
	alpha = max(alpha, ov.y);
	COLOR = vec4(clamp(col, vec3(0.0), vec3(alpha)), alpha);
}
