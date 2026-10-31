shader_type canvas_item;
render_mode blend_disabled;

uniform float view = 0.0;
uniform int view_mode = 0;
uniform bool grid = false;
uniform int fit = 0;
uniform float zoom = 1.0;
uniform float pan_x = 0.0;
uniform float pan_y = 0.0;
uniform float grid_gap = 0.01;
uniform bool grid_border = true;
uniform int layout = 0;
uniform int split_fit = 1;
uniform int solo = -1;
uniform int region_out = 0;
uniform int grid_cols = 0;
uniform vec2 canvas_px = vec2(1920.0, 1080.0);
uniform vec4 source_box = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool placing = false;
uniform vec2 place0 = vec2(0.2, 0.2);
uniform vec2 place1 = vec2(0.8, 0.8);
uniform vec2 place2 = vec2(0.2, 0.8);
uniform vec2 place3 = vec2(0.8, 0.2);
uniform vec2 place4 = vec2(0.2, 0.2);
uniform vec2 place5 = vec2(0.8, 0.8);
uniform vec2 place6 = vec2(0.2, 0.8);
uniform vec2 place7 = vec2(0.8, 0.2);
uniform float size0 = 0.3;
uniform float size1 = 0.3;
uniform float size2 = 0.3;
uniform float size3 = 0.3;
uniform float size4 = 0.3;
uniform float size5 = 0.3;
uniform float size6 = 0.3;
uniform float size7 = 0.3;
uniform int crop_count = 2;
uniform vec4 crop0 = vec4(0.0, 0.0, 0.5, 1.0);
uniform vec4 crop1 = vec4(0.5, 0.0, 0.5, 1.0);
uniform vec4 crop2 = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 crop3 = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 crop4 = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 crop5 = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 crop6 = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 crop7 = vec4(0.0, 0.0, 1.0, 1.0);
uniform float crop_rot0 = 0.0;
uniform float crop_rot1 = 0.0;
uniform float crop_rot2 = 0.0;
uniform float crop_rot3 = 0.0;
uniform float crop_rot4 = 0.0;
uniform float crop_rot5 = 0.0;
uniform float crop_rot6 = 0.0;
uniform float crop_rot7 = 0.0;
uniform float turn0 = 0.0;
uniform float turn1 = 0.0;
uniform float turn2 = 0.0;
uniform float turn3 = 0.0;
uniform float turn4 = 0.0;
uniform float turn5 = 0.0;
uniform float turn6 = 0.0;
uniform float turn7 = 0.0;
uniform int cut_on = 0;
uniform vec4 cut_a0 = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 cut_a1 = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 cut_a2 = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 cut_a3 = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 cut_a4 = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 cut_a5 = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 cut_a6 = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 cut_a7 = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 cut_b0 = vec4(1.0, 1.0, 0.0, 1.0);
uniform vec4 cut_b1 = vec4(1.0, 1.0, 0.0, 1.0);
uniform vec4 cut_b2 = vec4(1.0, 1.0, 0.0, 1.0);
uniform vec4 cut_b3 = vec4(1.0, 1.0, 0.0, 1.0);
uniform vec4 cut_b4 = vec4(1.0, 1.0, 0.0, 1.0);
uniform vec4 cut_b5 = vec4(1.0, 1.0, 0.0, 1.0);
uniform vec4 cut_b6 = vec4(1.0, 1.0, 0.0, 1.0);
uniform vec4 cut_b7 = vec4(1.0, 1.0, 0.0, 1.0);
uniform vec2 tex_size = vec2(1920.0, 1080.0);
uniform vec2 seq_size = vec2(1920.0, 1080.0);
uniform vec4 active_colour : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform int region_own = 0;
uniform int sync_mode = 0;
uniform int sync_show = 255;
uniform sampler2D region_tex0 : filter_linear, repeat_disable;
uniform sampler2D region_tex1 : filter_linear, repeat_disable;
uniform sampler2D region_tex2 : filter_linear, repeat_disable;
uniform sampler2D region_tex3 : filter_linear, repeat_disable;
uniform sampler2D region_tex4 : filter_linear, repeat_disable;
uniform sampler2D region_tex5 : filter_linear, repeat_disable;
uniform sampler2D region_tex6 : filter_linear, repeat_disable;
uniform sampler2D region_tex7 : filter_linear, repeat_disable;

vec4 crop_at(int i) {
	if (i == 0) { return crop0; }
	if (i == 1) { return crop1; }
	if (i == 2) { return crop2; }
	if (i == 3) { return crop3; }
	if (i == 4) { return crop4; }
	if (i == 5) { return crop5; }
	if (i == 6) { return crop6; }
	return crop7;
}

float crop_rot_at(int i) {
	if (i == 0) { return crop_rot0; }
	if (i == 1) { return crop_rot1; }
	if (i == 2) { return crop_rot2; }
	if (i == 3) { return crop_rot3; }
	if (i == 4) { return crop_rot4; }
	if (i == 5) { return crop_rot5; }
	if (i == 6) { return crop_rot6; }
	return crop_rot7;
}

bool bit_on(int bits, int i) {
	return ((bits >> i) & 1) == 1;
}

vec4 cut_a_at(int i) {
	if (i == 0) { return cut_a0; }
	if (i == 1) { return cut_a1; }
	if (i == 2) { return cut_a2; }
	if (i == 3) { return cut_a3; }
	if (i == 4) { return cut_a4; }
	if (i == 5) { return cut_a5; }
	if (i == 6) { return cut_a6; }
	return cut_a7;
}

vec4 cut_b_at(int i) {
	if (i == 0) { return cut_b0; }
	if (i == 1) { return cut_b1; }
	if (i == 2) { return cut_b2; }
	if (i == 3) { return cut_b3; }
	if (i == 4) { return cut_b4; }
	if (i == 5) { return cut_b5; }
	if (i == 6) { return cut_b6; }
	return cut_b7;
}

float turn_at(int i) {
	if (i == 0) { return turn0; }
	if (i == 1) { return turn1; }
	if (i == 2) { return turn2; }
	if (i == 3) { return turn3; }
	if (i == 4) { return turn4; }
	if (i == 5) { return turn5; }
	if (i == 6) { return turn6; }
	return turn7;
}

bool crosses(vec2 p, vec2 a, vec2 b) {
	if ((a.y > p.y) != (b.y > p.y)) {
		return p.x < a.x + (p.y - a.y) / (b.y - a.y) * (b.x - a.x);
	}
	return false;
}

bool cut_keeps(int i, vec2 at) {
	if (!bit_on(cut_on, i)) {
		return true;
	}
	vec4 a = cut_a_at(i);
	vec4 b = cut_b_at(i);
	bool inside = false;
	if (crosses(at, a.xy, a.zw)) { inside = !inside; }
	if (crosses(at, a.zw, b.xy)) { inside = !inside; }
	if (crosses(at, b.xy, b.zw)) { inside = !inside; }
	if (crosses(at, b.zw, a.xy)) { inside = !inside; }
	return inside;
}

vec4 fetch(sampler2D main_tex, int i, vec2 uv) {
	if (!bit_on(region_own, i)) {
		return texture(main_tex, uv);
	}
	if (i == 0) { return texture(region_tex0, uv); }
	if (i == 1) { return texture(region_tex1, uv); }
	if (i == 2) { return texture(region_tex2, uv); }
	if (i == 3) { return texture(region_tex3, uv); }
	if (i == 4) { return texture(region_tex4, uv); }
	if (i == 5) { return texture(region_tex5, uv); }
	if (i == 6) { return texture(region_tex6, uv); }
	return texture(region_tex7, uv);
}

int active_index() {
	int n = max(crop_count, 1);
	if (view_mode == 1) {
		return clamp(int(floor(clamp(view, 0.0, 0.99999) * float(n))), 0, n - 1);
	}
	return clamp(int(floor(view + 0.5)), 0, n - 1);
}

vec4 sample_region(sampler2D tex, int i, vec2 cell_uv, vec2 cell_px, int mode, bool zoomed) {
	vec4 r = crop_at(i);
	float ang = crop_rot_at(i);
	float src_aspect = max(r.z * tex_size.x, 1.0) / max(r.w * tex_size.y, 1.0);
	float dst_aspect = max(cell_px.x, 1.0) / max(cell_px.y, 1.0);
	vec2 scale = vec2(1.0);
	if (mode == 0) {
		if (src_aspect > dst_aspect) {
			scale = vec2(1.0, dst_aspect / src_aspect);
		} else {
			scale = vec2(src_aspect / dst_aspect, 1.0);
		}
	} else if (mode == 1) {
		if (src_aspect > dst_aspect) {
			scale = vec2(src_aspect / dst_aspect, 1.0);
		} else {
			scale = vec2(1.0, dst_aspect / src_aspect);
		}
	}
	vec2 local = (cell_uv - 0.5) / scale;
	if (zoomed) {
		local = local / max(zoom, 0.01) + vec2(pan_x, -pan_y) * 0.5;
	}
	if (!cut_keeps(i, local + 0.5)) {
		return vec4(0.0);
	}
	if (mode == 0 && (abs(local.x) > 0.5 || abs(local.y) > 0.5)) {
		return vec4(0.0);
	}
	vec2 uv = vec2(0.0);
	if (abs(ang) < 0.0001) {
		uv = r.xy + (local + 0.5) * r.zw;
		if (uv.x < r.x || uv.x > r.x + r.z || uv.y < r.y || uv.y > r.y + r.w) {
			return vec4(0.0);
		}
	} else {
		vec2 half_px = vec2(r.z * tex_size.x, r.w * tex_size.y) * 0.5;
		vec2 p = local * 2.0 * half_px;
		float ca = cos(ang);
		float sa = sin(ang);
		vec2 rp = vec2(p.x * ca - p.y * sa, p.x * sa + p.y * ca);
		uv = (r.xy + r.zw * 0.5) + rp / tex_size;
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			return vec4(0.0);
		}
	}
	return fetch(tex, i, uv);
}

int count_in(int bits, int n) {
	int count = 0;
	for (int i = 0; i < 8; i++) {
		if (i < n && bit_on(bits, i)) {
			count += 1;
		}
	}
	return count;
}

int nth_in(int bits, int n, int k) {
	int seen = 0;
	for (int i = 0; i < 8; i++) {
		if (i < n && bit_on(bits, i)) {
			if (seen == k) {
				return i;
			}
			seen += 1;
		}
	}
	return -1;
}

vec4 grid_cell(sampler2D tex, int count, int n, int active, vec2 at, int bits, int want_cols, bool border) {
	int cols = want_cols > 0 ? min(want_cols, count) : int(ceil(sqrt(float(count))));
	int rows = int(ceil(float(count) / float(cols)));
	float gap = grid_gap;
	vec2 cell_size = vec2(1.0 / float(cols), 1.0 / float(rows));
	int cx = clamp(int(floor(at.x / cell_size.x)), 0, cols - 1);
	int cy = clamp(int(floor(at.y / cell_size.y)), 0, rows - 1);
	int slot = cy * cols + cx;
	vec2 cell_uv = (at - vec2(float(cx), float(cy)) * cell_size) / cell_size;
	vec2 inner = (cell_uv - gap) / max(1.0 - gap * 2.0, 0.0001);
	if (slot >= count || inner.x < 0.0 || inner.x > 1.0 || inner.y < 0.0 || inner.y > 1.0) {
		return vec4(0.0);
	}
	int idx = nth_in(bits, n, slot);
	if (idx < 0) {
		return vec4(0.0);
	}
	vec2 cell_px = cell_size * canvas_px * (1.0 - gap * 2.0);
	vec4 c = sample_region(tex, idx, inner, cell_px, fit, true);
	if (border && idx == active) {
		vec2 edge = vec2(3.0) / max(cell_size * seq_size * (1.0 - gap * 2.0), vec2(1.0));
		if (inner.x < edge.x || inner.x > 1.0 - edge.x || inner.y < edge.y || inner.y > 1.0 - edge.y) {
			c = active_colour;
		}
	}
	return c;
}

vec4 blended(sampler2D tex, int n, vec2 at) {
	vec4 acc = vec4(0.0);
	float count = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i < n && bit_on(sync_show, i)) {
			vec4 c = sample_region(tex, i, at, canvas_px, fit, true);
			acc += vec4(c.rgb * c.a, c.a);
			count += 1.0;
		}
	}
	if (count < 0.5) {
		return vec4(0.0);
	}
	acc /= count;
	if (acc.a > 0.0001) {
		return vec4(acc.rgb / acc.a, acc.a);
	}
	return vec4(0.0);
}

vec2 place_at(int i) {
	if (i == 0) { return place0; }
	if (i == 1) { return place1; }
	if (i == 2) { return place2; }
	if (i == 3) { return place3; }
	if (i == 4) { return place4; }
	if (i == 5) { return place5; }
	if (i == 6) { return place6; }
	return place7;
}

float size_at(int i) {
	if (i == 0) { return size0; }
	if (i == 1) { return size1; }
	if (i == 2) { return size2; }
	if (i == 3) { return size3; }
	if (i == 4) { return size4; }
	if (i == 5) { return size5; }
	if (i == 6) { return size6; }
	return size7;
}

int shown_bits(int n) {
	return ~region_out & ((1 << n) - 1);
}

vec4 inset_at(sampler2D tex, int i, vec2 at) {
	vec4 r = crop_at(i);
	float ar = max(r.z * tex_size.x, 1.0) / max(r.w * tex_size.y, 1.0);
	float ca = max(canvas_px.x, 1.0) / max(canvas_px.y, 1.0);
	vec2 full = ar > ca ? vec2(1.0, ca / ar) : vec2(ar / ca, 1.0);
	vec2 sz = full * clamp(size_at(i), 0.0, 1.0);
	if (sz.x <= 0.0 || sz.y <= 0.0) {
		return vec4(0.0);
	}
	vec2 spot = at;
	float tn = radians(turn_at(i));
	if (abs(tn) > 0.000001) {
		vec2 d = (at - place_at(i)) * canvas_px;
		float tc = cos(tn);
		float ts = sin(tn);
		spot = place_at(i) + vec2(tc * d.x + ts * d.y, -ts * d.x + tc * d.y) / max(canvas_px, vec2(1.0));
	}
	vec2 cell_uv = (spot - (place_at(i) - sz * 0.5)) / sz;
	if (cell_uv.x < 0.0 || cell_uv.x > 1.0 || cell_uv.y < 0.0 || cell_uv.y > 1.0) {
		return vec4(0.0);
	}
	return sample_region(tex, i, cell_uv, sz * canvas_px, 2, false);
}

vec4 with_insets(sampler2D tex, int n, int active, vec2 at, vec4 base) {
	vec4 out_col = base;
	int shown = shown_bits(n);
	for (int i = 0; i < 8; i++) {
		if (i < n && i != active && bit_on(shown, i)) {
			vec4 c = inset_at(tex, i, at);
			out_col = vec4(mix(out_col.rgb, c.rgb, c.a), c.a + out_col.a * (1.0 - c.a));
		}
	}
	return out_col;
}

vec4 split_cell(sampler2D tex, int n, vec2 at, bool across) {
	int shown = shown_bits(n);
	int count = count_in(shown, n);
	if (count <= 0) {
		return vec4(0.0);
	}
	float k = across ? at.x : at.y;
	int slot = clamp(int(floor(k * float(count))), 0, count - 1);
	int idx = nth_in(shown, n, slot);
	if (idx < 0) {
		return vec4(0.0);
	}
	vec2 cell_uv = at;
	vec2 cell_px = canvas_px;
	if (across) {
		cell_uv.x = at.x * float(count) - float(slot);
		cell_px.x = canvas_px.x / float(count);
	} else {
		cell_uv.y = at.y * float(count) - float(slot);
		cell_px.y = canvas_px.y / float(count);
	}
	return sample_region(tex, idx, cell_uv, cell_px, split_fit, true);
}

vec4 source_view(sampler2D tex, vec2 at) {
	vec2 uv = (at - source_box.xy) / max(source_box.zw, vec2(0.0001));
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	return texture(tex, uv);
}

void fragment() {
	int n = clamp(crop_count, 1, 8);
	int active = active_index();
	if (placing) {
		COLOR = source_view(TEXTURE, UV);
	} else if (sync_mode == 1) {
		int count = count_in(sync_show, n);
		COLOR = count > 0 ? grid_cell(TEXTURE, count, n, active, UV, sync_show, 0, false) : vec4(0.0);
	} else if (sync_mode == 2) {
		COLOR = blended(TEXTURE, n, UV);
	} else if (solo >= 0) {
		COLOR = inset_at(TEXTURE, min(solo, n - 1), UV);
	} else if (grid) {
		int shown = shown_bits(n);
		int count = count_in(shown, n);
		COLOR = count > 0 ? grid_cell(TEXTURE, count, n, active, UV, shown, grid_cols, grid_border) : vec4(0.0);
	} else if (layout == 1 || layout == 2) {
		COLOR = split_cell(TEXTURE, n, UV, layout == 1);
	} else {
		vec4 base = sample_region(TEXTURE, active, UV, canvas_px, fit, true);
		if (layout == 3) {
			base = with_insets(TEXTURE, n, active, UV, base);
		}
		COLOR = base;
	}
}
