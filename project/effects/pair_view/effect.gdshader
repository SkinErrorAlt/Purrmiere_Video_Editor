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
uniform int border_on = 0;
uniform int border_solid = 0;
uniform int border_moving = 0;
uniform vec4 border_win0 = vec4(0.11, 0.11, 0.78, 0.78);
uniform vec4 border_win1 = vec4(0.11, 0.11, 0.78, 0.78);
uniform vec4 border_win2 = vec4(0.11, 0.11, 0.78, 0.78);
uniform vec4 border_win3 = vec4(0.11, 0.11, 0.78, 0.78);
uniform vec4 border_win4 = vec4(0.11, 0.11, 0.78, 0.78);
uniform vec4 border_win5 = vec4(0.11, 0.11, 0.78, 0.78);
uniform vec4 border_win6 = vec4(0.11, 0.11, 0.78, 0.78);
uniform vec4 border_win7 = vec4(0.11, 0.11, 0.78, 0.78);
uniform float border_zoom0 = 1.0;
uniform float border_zoom1 = 1.0;
uniform float border_zoom2 = 1.0;
uniform float border_zoom3 = 1.0;
uniform float border_zoom4 = 1.0;
uniform float border_zoom5 = 1.0;
uniform float border_zoom6 = 1.0;
uniform float border_zoom7 = 1.0;
uniform float border_inset0 = 0.0;
uniform float border_inset1 = 0.0;
uniform float border_inset2 = 0.0;
uniform float border_inset3 = 0.0;
uniform float border_inset4 = 0.0;
uniform float border_inset5 = 0.0;
uniform float border_inset6 = 0.0;
uniform float border_inset7 = 0.0;
uniform vec4 border_cell0 = vec4(0.0);
uniform vec4 border_cell1 = vec4(0.0);
uniform vec4 border_cell2 = vec4(0.0);
uniform vec4 border_cell3 = vec4(0.0);
uniform vec4 border_cell4 = vec4(0.0);
uniform vec4 border_cell5 = vec4(0.0);
uniform vec4 border_cell6 = vec4(0.0);
uniform vec4 border_cell7 = vec4(0.0);
uniform int label_show = 0;
uniform float label_size = 0.075;
uniform float label_plate = 0.75;
uniform vec4 label_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 label_px = vec2(384.0, 72.0);
uniform float label_w0 = 0.0;
uniform float label_w1 = 0.0;
uniform float label_w2 = 0.0;
uniform float label_w3 = 0.0;
uniform float label_w4 = 0.0;
uniform float label_w5 = 0.0;
uniform float label_w6 = 0.0;
uniform float label_w7 = 0.0;
uniform sampler2D label_tex : filter_linear, repeat_disable, hint_default_transparent;
uniform sampler2DArray border_atlas : filter_linear_mipmap, repeat_disable;
uniform sampler2DArray border_reel : filter_linear_mipmap, repeat_disable;
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

vec4 border_cell_at(int i) {
	if (i == 0) { return border_cell0; }
	if (i == 1) { return border_cell1; }
	if (i == 2) { return border_cell2; }
	if (i == 3) { return border_cell3; }
	if (i == 4) { return border_cell4; }
	if (i == 5) { return border_cell5; }
	if (i == 6) { return border_cell6; }
	return border_cell7;
}

vec2 border_size_at(int i) {
	return border_cell_at(i).xy;
}

vec4 border_at(int i, vec2 uv) {
	vec4 cell = border_cell_at(i);
	if (bit_on(border_moving, i)) {
		vec2 reel_full = max(vec2(textureSize(border_reel, 0).xy), vec2(1.0));
		return texture(border_reel, vec3(uv * cell.xy / reel_full, cell.z));
	}
	vec2 full = max(vec2(textureSize(border_atlas, 0).xy), vec2(1.0));
	return texture(border_atlas, vec3(uv * cell.xy / full, cell.z));
}

vec4 border_win_at(int i) {
	if (i == 0) { return border_win0; }
	if (i == 1) { return border_win1; }
	if (i == 2) { return border_win2; }
	if (i == 3) { return border_win3; }
	if (i == 4) { return border_win4; }
	if (i == 5) { return border_win5; }
	if (i == 6) { return border_win6; }
	return border_win7;
}

float border_zoom_at(int i) {
	if (i == 0) { return border_zoom0; }
	if (i == 1) { return border_zoom1; }
	if (i == 2) { return border_zoom2; }
	if (i == 3) { return border_zoom3; }
	if (i == 4) { return border_zoom4; }
	if (i == 5) { return border_zoom5; }
	if (i == 6) { return border_zoom6; }
	return border_zoom7;
}

float border_inset_at(int i) {
	if (i == 0) { return border_inset0; }
	if (i == 1) { return border_inset1; }
	if (i == 2) { return border_inset2; }
	if (i == 3) { return border_inset3; }
	if (i == 4) { return border_inset4; }
	if (i == 5) { return border_inset5; }
	if (i == 6) { return border_inset6; }
	return border_inset7;
}

float label_w_at(int i) {
	if (i == 0) { return label_w0; }
	if (i == 1) { return label_w1; }
	if (i == 2) { return label_w2; }
	if (i == 3) { return label_w3; }
	if (i == 4) { return label_w4; }
	if (i == 5) { return label_w5; }
	if (i == 6) { return label_w6; }
	return label_w7;
}

vec4 window_at(int i) {
	vec4 w = border_win_at(i);
	float k = min(w.z, w.w) * clamp(border_inset_at(i), -0.4, 0.45);
	return vec4(w.x + k, w.y + k, max(w.z - k * 2.0, 0.01), max(w.w - k * 2.0, 0.01));
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

vec4 sample_region(sampler2D tex, int i, vec2 cell_uv, vec2 cell_px, int mode, bool zoomed, float vz) {
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
		local = local / max(zoom * vz, 0.01) + vec2(pan_x, -pan_y) * 0.5;
	} else if (vz != 1.0) {
		local = local / max(vz, 0.01);
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

vec4 label_over(vec4 base, int i, vec2 cell_uv, vec2 cell_px, vec4 box, float rail) {
	float used = label_w_at(i);
	if (label_show == 0 || used <= 0.0) {
		return base;
	}
	vec2 px = max(cell_px, vec2(1.0));
	float th = clamp(label_size, 0.004, 0.9) * px.y;
	float tw = th * (used * label_px.x) / max(label_px.y, 1.0);
	if (tw < 0.5) {
		return base;
	}
	vec2 pad = vec2(th * 0.52, th * 0.26);
	vec2 plate = vec2(tw, th) + pad * 2.0;
	float lip = rail * px.y;
	float bottom = (box.y + box.w) * px.y;
	float on_rail = bottom - lip >= plate.y ? (lip + bottom) * 0.5 : lip - plate.y * 0.62;
	float cy = label_show == 1 ? on_rail : bottom + plate.y * 0.62;
	float edge = plate.y * 0.62;
	cy = clamp(cy, min(edge, px.y * 0.5), max(px.y - edge, px.y * 0.5));
	vec2 mid = vec2(px.x * 0.5, cy);
	vec2 p = cell_uv * px;
	float r = min(plate.y * 0.34, plate.x * 0.5);
	vec2 d = abs(p - mid) - plate * 0.5 + vec2(r);
	float sd = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
	if (sd > 1.0) {
		return base;
	}
	vec2 tl = mid - vec2(tw, th) * 0.5;
	vec2 tuv = (p - tl) / vec2(tw, th);
	vec2 tap = vec2(1.2 / max(tw, 1.0), 1.2 / max(th, 1.0));
	float cov = 0.0;
	float ring = 0.0;
	for (int k = 0; k < 9; k++) {
		vec2 q = tuv + vec2(float(k % 3) - 1.0, float(k / 3) - 1.0) * tap;
		float c = 0.0;
		if (q.x >= 0.0 && q.x <= 1.0 && q.y >= 0.0 && q.y <= 1.0) {
			c = texture(label_tex, vec2(q.x * used, (float(i) + q.y) * 0.125)).r;
		}
		if (k == 4) {
			cov = c;
		}
		ring = max(ring, c);
	}
	float pa = clamp(label_plate, 0.0, 1.0) * (1.0 - smoothstep(-0.75, 0.75, sd));
	float grad = clamp(0.5 + (p.y - cy) / max(plate.y, 1.0), 0.0, 1.0);
	vec3 plate_col = vec3(0.045, 0.05, 0.065) * mix(1.9, 0.75, grad);
	base = vec4(mix(base.rgb, plate_col, pa), pa + base.a * (1.0 - pa));
	base.rgb += vec3(0.22) * (1.0 - smoothstep(0.0, 1.6, abs(sd))) * pa * (1.0 - grad);
	float shade = clamp(ring - cov, 0.0, 1.0) * 0.8;
	base = vec4(mix(base.rgb, vec3(0.0), shade), shade + base.a * (1.0 - shade));
	float ta = cov * clamp(label_colour.a, 0.0, 1.0);
	return vec4(mix(base.rgb, label_colour.rgb, ta), ta + base.a * (1.0 - ta));
}

vec4 framed_by(sampler2D tex, int i, vec2 cell_uv, vec2 cell_px, bool zoomed) {
	vec2 bpx = border_size_at(i);
	float ba = max(bpx.x, 1.0) / max(bpx.y, 1.0);
	float da = max(cell_px.x, 1.0) / max(cell_px.y, 1.0);
	vec2 bs = ba > da ? vec2(1.0, da / ba) : vec2(ba / da, 1.0);
	vec4 box = vec4((1.0 - bs.x) * 0.5, (1.0 - bs.y) * 0.5, bs.x, bs.y);
	vec2 b_uv = (cell_uv - box.xy) / box.zw;
	vec4 win = window_at(i);
	vec2 f_uv = (b_uv - win.xy) / win.zw;
	vec4 col = vec4(0.0);
	bool in_win = f_uv.x >= 0.0 && f_uv.x <= 1.0 && f_uv.y >= 0.0 && f_uv.y <= 1.0;
	if (in_win) {
		col = sample_region(tex, i, f_uv, win.zw * box.zw * cell_px, 1, zoomed, border_zoom_at(i));
	}
	bool on_frame = b_uv.x >= 0.0 && b_uv.x <= 1.0 && b_uv.y >= 0.0 && b_uv.y <= 1.0;
	if (on_frame && !(bit_on(border_solid, i) && in_win)) {
		vec4 bc = border_at(i, b_uv);
		col = vec4(mix(col.rgb, bc.rgb, bc.a), bc.a + col.a * (1.0 - bc.a));
	}
	return label_over(col, i, cell_uv, cell_px, box, box.y + (win.y + win.w) * box.w);
}

vec4 framed(sampler2D tex, int i, vec2 cell_uv, vec2 cell_px, int mode) {
	if (!bit_on(border_on, i)) {
		return label_over(sample_region(tex, i, cell_uv, cell_px, mode, true, 1.0), i, cell_uv, cell_px, vec4(0.0, 0.0, 1.0, 1.0), 1.0);
	}
	return framed_by(tex, i, cell_uv, cell_px, true);
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
	vec4 c = framed(tex, idx, inner, cell_px, fit);
	if (border && idx == active && !bit_on(border_on, idx)) {
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
			vec4 c = sample_region(tex, i, at, canvas_px, fit, true, 1.0);
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
	bool with_frame = bit_on(border_on, i);
	if (with_frame) {
		vec2 bpx = border_size_at(i);
		ar = max(bpx.x, 1.0) / max(bpx.y, 1.0);
	}
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
	if (with_frame) {
		return framed_by(tex, i, cell_uv, sz * canvas_px, false);
	}
	return label_over(sample_region(tex, i, cell_uv, sz * canvas_px, 2, false, 1.0), i, cell_uv, sz * canvas_px, vec4(0.0, 0.0, 1.0, 1.0), 1.0);
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
	return framed(tex, idx, cell_uv, cell_px, split_fit);
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
		vec4 base = framed(TEXTURE, active, UV, canvas_px, fit);
		if (layout == 3) {
			base = with_insets(TEXTURE, n, active, UV, base);
		}
		COLOR = base;
	}
}
