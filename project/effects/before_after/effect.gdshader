shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D source_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int mode : hint_range(0, 1) = 0;
uniform vec2 split = vec2(0.5, 0.5);
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform bool swap = false;
uniform float line_width : hint_range(0.0, 10.0) = 2.0;
uniform vec4 line_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool labels = true;
uniform float label_size : hint_range(0.5, 3.0) = 1.0;

ivec2 glyph_bits(int g) {
	if (g == 0) {
		return ivec2(1001022, 31281);
	} else if (g == 1) {
		return ivec2(999967, 32272);
	} else if (g == 2) {
		return ivec2(999967, 16912);
	} else if (g == 3) {
		return ivec2(575022, 14897);
	} else if (g == 4) {
		return ivec2(1001022, 18004);
	} else if (g == 5) {
		return ivec2(1033774, 17969);
	} else if (g == 6) {
		return ivec2(135327, 4228);
	}
	return ivec2(0, 0);
}

int letter(bool after, int i) {
	if (after) {
		if (i == 0) {
			return 5;
		} else if (i == 1) {
			return 2;
		} else if (i == 2) {
			return 6;
		} else if (i == 3) {
			return 1;
		}
		return 4;
	}
	if (i == 0) {
		return 0;
	} else if (i == 1) {
		return 1;
	} else if (i == 2) {
		return 2;
	} else if (i == 3) {
		return 3;
	} else if (i == 4) {
		return 4;
	}
	return 1;
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

vec2 label_cover(vec2 p, vec2 origin, float cell, bool after) {
	int count = after ? 5 : 6;
	vec2 box = vec2(float(count) * 6.0 - 1.0, 7.0) * cell;
	float pad = cell * 2.0;
	vec2 q = p - origin;
	float in_box = (q.x >= -pad && q.y >= -pad && q.x <= box.x + pad && q.y <= box.y + pad) ? 1.0 : 0.0;
	float ink = 0.0;
	vec2 g = q / cell;
	if (g.x >= 0.0 && g.y >= 0.0 && g.y < 7.0) {
		int i = int(floor(g.x / 6.0));
		if (i < count) {
			ink = glyph_on(letter(after, i), vec2(g.x - float(i) * 6.0, g.y));
		}
	}
	return vec2(in_box, ink);
}

vec4 straight(vec4 c) {
	return c.a > 0.0001 ? vec4(clamp(c.rgb / c.a, 0.0, 1.0), c.a) : vec4(0.0);
}

void fragment() {
	vec2 full = max(tex_size, vec2(1.0));
	vec2 p = UV * full;
	vec4 outc;
	float line = 0.0;
	bool before_side = false;
	vec2 before_origin;
	vec2 after_origin;
	float cell = max(1.0, floor(full.y / 180.0 * 1.6 * label_size + 0.5));
	float margin = cell * 5.0;
	if (mode == 1) {
		float half_w = full.x * 0.5;
		bool right = p.x >= half_w;
		vec2 local = vec2((p.x - (right ? half_w : 0.0)) / half_w, (p.y - full.y * 0.25) / (full.y * 0.5));
		bool shows_before = right == swap;
		if (local.y < 0.0 || local.y > 1.0) {
			outc = vec4(0.0, 0.0, 0.0, 1.0);
		} else {
			outc = shows_before ? straight(texture(source_tex, local)) : straight(texture(TEXTURE, local));
		}
		float lw = line_width * px_scale;
		line = lw > 0.0 ? 1.0 - smoothstep(lw * 0.5, lw * 0.5 + 1.0, abs(p.x - half_w)) : 0.0;
		float top = full.y * 0.25 + margin * 0.6;
		vec2 left_origin = vec2(margin, top);
		vec2 right_origin = vec2(half_w + margin, top);
		before_origin = swap ? right_origin : left_origin;
		after_origin = swap ? left_origin : right_origin;
	} else {
		float ang = radians(angle);
		vec2 normal = vec2(cos(ang), sin(ang));
		float side = dot(p - split * full, normal);
		bool shows_before = (side < 0.0) != swap;
		outc = shows_before ? straight(texture(source_tex, UV)) : straight(texture(TEXTURE, UV));
		float lw = line_width * px_scale;
		line = lw > 0.0 ? 1.0 - smoothstep(lw * 0.5, lw * 0.5 + 1.0, abs(side)) : 0.0;
		vec2 left_origin = vec2(margin, margin);
		vec2 right_origin = vec2(full.x - margin - 29.0 * cell, margin);
		before_origin = swap ? vec2(full.x - margin - 35.0 * cell, margin) : left_origin;
		after_origin = swap ? left_origin : right_origin;
	}
	vec3 rgb = outc.rgb;
	float a = outc.a;
	rgb = mix(rgb, line_colour.rgb, line * line_colour.a);
	a = max(a, line * line_colour.a);
	if (labels) {
		vec2 lb = label_cover(p, before_origin, cell, false);
		vec2 la = label_cover(p, after_origin, cell, true);
		float box = max(lb.x, la.x);
		float ink = max(lb.y, la.y);
		rgb = mix(rgb, vec3(0.0), box * 0.55);
		rgb = mix(rgb, vec3(1.0), ink);
		a = max(a, box * 0.55);
	}
	COLOR = vec4(rgb * a, a);
}
