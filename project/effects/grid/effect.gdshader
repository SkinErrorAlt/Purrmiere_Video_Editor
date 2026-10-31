shader_type canvas_item;
render_mode blend_disabled;

uniform int cells = 2;
uniform int cols = 0;
uniform float gap = 0.02;
uniform vec4 bg : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform int fit = 0;
uniform int source = 0;
uniform bool sort_by_view = true;
uniform bool grid_border = false;
uniform float c0_x = 0.0;
uniform float c0_y = 0.0;
uniform float c0_scale = 1.0;
uniform float c0_rot = 0.0;
uniform int c0_crop = 0;
uniform float c1_x = 0.0;
uniform float c1_y = 0.0;
uniform float c1_scale = 1.0;
uniform float c1_rot = 0.0;
uniform int c1_crop = 0;
uniform float c2_x = 0.0;
uniform float c2_y = 0.0;
uniform float c2_scale = 1.0;
uniform float c2_rot = 0.0;
uniform int c2_crop = 0;
uniform float c3_x = 0.0;
uniform float c3_y = 0.0;
uniform float c3_scale = 1.0;
uniform float c3_rot = 0.0;
uniform int c3_crop = 0;
uniform float c4_x = 0.0;
uniform float c4_y = 0.0;
uniform float c4_scale = 1.0;
uniform float c4_rot = 0.0;
uniform int c4_crop = 0;
uniform float c5_x = 0.0;
uniform float c5_y = 0.0;
uniform float c5_scale = 1.0;
uniform float c5_rot = 0.0;
uniform int c5_crop = 0;
uniform int paired = 0;
uniform int crop_count = 0;
uniform float view = 0.0;
uniform int view_mode = 0;
uniform vec4 crop0 = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 crop1 = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 crop2 = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 crop3 = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 crop4 = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 crop5 = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 crop6 = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 crop7 = vec4(0.0, 0.0, 1.0, 1.0);
uniform sampler2D source_tex;
uniform vec2 tex_size = vec2(1920.0, 1080.0);
uniform vec2 seq_size = vec2(1920.0, 1080.0);
uniform vec4 active_colour : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform int region_own = 0;
uniform sampler2D region_tex0 : filter_linear, repeat_disable;
uniform sampler2D region_tex1 : filter_linear, repeat_disable;
uniform sampler2D region_tex2 : filter_linear, repeat_disable;
uniform sampler2D region_tex3 : filter_linear, repeat_disable;
uniform sampler2D region_tex4 : filter_linear, repeat_disable;
uniform sampler2D region_tex5 : filter_linear, repeat_disable;
uniform sampler2D region_tex6 : filter_linear, repeat_disable;
uniform sampler2D region_tex7 : filter_linear, repeat_disable;
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

vec4 fetch_source(int ri, vec2 uv) {
	if (!bit_on(region_own, ri)) {
		return texture(source_tex, uv);
	}
	if (ri == 0) { return texture(region_tex0, uv); }
	if (ri == 1) { return texture(region_tex1, uv); }
	if (ri == 2) { return texture(region_tex2, uv); }
	if (ri == 3) { return texture(region_tex3, uv); }
	if (ri == 4) { return texture(region_tex4, uv); }
	if (ri == 5) { return texture(region_tex5, uv); }
	if (ri == 6) { return texture(region_tex6, uv); }
	return texture(region_tex7, uv);
}

vec4 cell_transform(int i) {
	if (i == 0) { return vec4(c0_x, c0_y, c0_scale, c0_rot); }
	if (i == 1) { return vec4(c1_x, c1_y, c1_scale, c1_rot); }
	if (i == 2) { return vec4(c2_x, c2_y, c2_scale, c2_rot); }
	if (i == 3) { return vec4(c3_x, c3_y, c3_scale, c3_rot); }
	if (i == 4) { return vec4(c4_x, c4_y, c4_scale, c4_rot); }
	return vec4(c5_x, c5_y, c5_scale, c5_rot);
}

int cell_crop_override(int i) {
	if (i == 0) { return c0_crop; }
	if (i == 1) { return c1_crop; }
	if (i == 2) { return c2_crop; }
	if (i == 3) { return c3_crop; }
	if (i == 4) { return c4_crop; }
	return c5_crop;
}

int active_index() {
	int n = max(crop_count, 1);
	if (view_mode == 1) {
		return clamp(int(floor(clamp(view, 0.0, 0.99999) * float(n))), 0, n - 1);
	}
	return clamp(int(floor(view + 0.5)), 0, n - 1);
}

int crop_for_cell(int i, int active) {
	int over = cell_crop_override(i);
	if (over > 0) {
		return clamp(over - 1, 0, max(crop_count - 1, 0));
	}
	if (crop_count <= 0) {
		return 0;
	}
	int idx = i;
	if (sort_by_view) {
		if (i == 0) {
			idx = active;
		} else if (i <= active) {
			idx = i - 1;
		}
	}
	return idx % max(crop_count, 1);
}

vec4 sample_cell(vec4 r, int ri, vec2 cell_uv, vec2 cell_px, bool from_source, sampler2D tex) {
	float src_aspect = max(r.z * tex_size.x, 1.0) / max(r.w * tex_size.y, 1.0);
	float dst_aspect = max(cell_px.x, 1.0) / max(cell_px.y, 1.0);
	vec2 scale = vec2(1.0);
	if (fit == 0) {
		if (src_aspect > dst_aspect) {
			scale = vec2(1.0, dst_aspect / src_aspect);
		} else {
			scale = vec2(src_aspect / dst_aspect, 1.0);
		}
	} else if (fit == 1) {
		if (src_aspect > dst_aspect) {
			scale = vec2(src_aspect / dst_aspect, 1.0);
		} else {
			scale = vec2(1.0, dst_aspect / src_aspect);
		}
	}
	vec2 local = (cell_uv - 0.5) / scale;
	if (fit == 0 && (abs(local.x) > 0.5 || abs(local.y) > 0.5)) {
		return vec4(0.0);
	}
	if (from_source && !cut_keeps(ri, local + 0.5)) {
		return vec4(0.0);
	}
	vec2 uv = r.xy + (local + 0.5) * r.zw;
	if (uv.x < r.x || uv.x > r.x + r.z || uv.y < r.y || uv.y > r.y + r.w) {
		return vec4(0.0);
	}
	if (from_source) {
		return fetch_source(ri, uv);
	}
	return texture(tex, uv);
}

void fragment() {
	int n = clamp(cells, 1, 6);
	int ncols = cols > 0 ? min(cols, n) : int(ceil(sqrt(float(n))));
	int nrows = (n + ncols - 1) / ncols;
	float cw = max((1.0 - gap * float(ncols + 1)) / float(ncols), 0.02);
	float ch = max((1.0 - gap * float(nrows + 1)) / float(nrows), 0.02);
	bool from_source = (source == 0 && paired == 1 && crop_count > 0);
	int active = active_index();
	vec4 out_col = bg;
	for (int i = 0; i < 6; i++) {
		if (i >= n) {
			break;
		}
		int col = i % ncols;
		int row = i / ncols;
		int in_row = (row == nrows - 1) ? (n - row * ncols) : ncols;
		float shift = float(ncols - in_row) * (cw + gap) * 0.5;
		vec2 origin = vec2(gap + float(col) * (cw + gap) + shift, gap + float(row) * (ch + gap));
		vec2 rect_size = vec2(cw, ch);
		vec4 tf = cell_transform(i);
		vec2 centre = origin + rect_size * 0.5 + vec2(tf.x, -tf.y) * 0.5;
		vec2 dpx = (UV - centre) * tex_size;
		float a = radians(-tf.w);
		float cs = cos(a);
		float sn = sin(a);
		vec2 rot = vec2(dpx.x * cs - dpx.y * sn, dpx.x * sn + dpx.y * cs);
		vec2 local = rot / max(tf.z, 0.01) / tex_size;
		vec2 half_size = rect_size * 0.5;
		if (abs(local.x) <= half_size.x && abs(local.y) <= half_size.y) {
			vec2 cell_uv = (local + half_size) / rect_size;
			vec2 cell_px = rect_size * tex_size * tf.z;
			int ri = crop_for_cell(i, active);
			vec4 r = from_source ? crop_at(ri) : vec4(0.0, 0.0, 1.0, 1.0);
			vec4 c = sample_cell(r, ri, cell_uv, cell_px, from_source, TEXTURE);
			if (grid_border && from_source && ri == active) {
				vec2 edge = vec2(3.0) / max(cell_px, vec2(1.0));
				if (cell_uv.x < edge.x || cell_uv.x > 1.0 - edge.x || cell_uv.y < edge.y || cell_uv.y > 1.0 - edge.y) {
					c = active_colour;
				}
			}
			out_col = mix(out_col, c, c.a);
		}
	}
	COLOR = out_col;
}
