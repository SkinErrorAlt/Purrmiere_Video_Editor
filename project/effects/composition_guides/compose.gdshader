shader_type canvas_item;
render_mode blend_disabled;

uniform int guide = 1;
uniform int turn = 2;
uniform vec4 colour : source_color = vec4(1.0, 0.85, 0.25, 0.9);
uniform float width : hint_range(0.5, 8.0) = 1.5;
uniform float extra : hint_range(0.0, 1.0) = 0.45;

const float PHI = 1.6180339887;

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0000001), 0.0, 1.0);
	return length(pa - ba * h);
}

vec2 foot(vec2 p, vec2 a, vec2 b) {
	vec2 ba = b - a;
	return a + ba * dot(p - a, ba) / max(dot(ba, ba), 0.0000001);
}

vec2 hit_edge(vec2 from, vec2 dir, vec2 res) {
	float t = 1000000.0;
	if (abs(dir.x) > 0.000001) {
		float tx = dir.x > 0.0 ? (res.x - from.x) / dir.x : -from.x / dir.x;
		if (tx > 0.001) { t = min(t, tx); }
	}
	if (abs(dir.y) > 0.000001) {
		float ty = dir.y > 0.0 ? (res.y - from.y) / dir.y : -from.y / dir.y;
		if (ty > 0.001) { t = min(t, ty); }
	}
	return from + dir * (t < 999999.0 ? t : 0.0);
}

float line_cov(float d, float hw) {
	return clamp(hw + 0.5 - d, 0.0, 1.0);
}

vec2 orient(vec2 uv) {
	vec2 o = uv;
	if (turn == 0 || turn == 3) {
		o.x = 1.0 - o.x;
	}
	if (turn == 0 || turn == 1) {
		o.y = 1.0 - o.y;
	}
	return o;
}

void fragment() {
	vec4 pic = texture(TEXTURE, UV);
	vec2 res = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float hw = clamp(width, 0.5, 8.0) * 0.5;
	float main_l = 0.0;
	float faint = 0.0;
	if (guide == 0) {
		float a = 1.0 / (PHI * PHI);
		float b = 1.0 / PHI;
		vec2 px = UV * res;
		main_l = max(main_l, line_cov(abs(px.x - a * res.x), hw));
		main_l = max(main_l, line_cov(abs(px.x - b * res.x), hw));
		main_l = max(main_l, line_cov(abs(px.y - a * res.y), hw));
		main_l = max(main_l, line_cov(abs(px.y - b * res.y), hw));
	} else if (guide == 1) {
		vec2 o = orient(UV);
		vec2 g = vec2(o.x * PHI, o.y);
		vec2 to_px = res / vec2(PHI, 1.0);
		vec4 r = vec4(0.0, 0.0, PHI, 1.0);
		float best = 1000000.0;
		float rect_d = 1000000.0;
		for (int i = 0; i < 12; i++) {
			int side = i % 4;
			float s = (side == 0 || side == 2) ? r.w : r.z;
			vec4 sq;
			vec2 c;
			if (side == 0) {
				sq = vec4(r.x, r.y, s, s);
				c = vec2(r.x + s, r.y + s);
				r = vec4(r.x + s, r.y, r.z - s, r.w);
			} else if (side == 1) {
				sq = vec4(r.x, r.y, s, s);
				c = vec2(r.x, r.y + s);
				r = vec4(r.x, r.y + s, r.z, r.w - s);
			} else if (side == 2) {
				sq = vec4(r.x + r.z - s, r.y, s, s);
				c = vec2(r.x + r.z - s, r.y);
				r = vec4(r.x, r.y, r.z - s, r.w);
			} else {
				sq = vec4(r.x, r.y + r.w - s, s, s);
				c = vec2(r.x + s, r.y + r.w - s);
				r = vec4(r.x, r.y, r.z, r.w - s);
			}
			vec2 lo = sq.xy - vec2(0.00001);
			vec2 hi = sq.xy + sq.zw + vec2(0.00001);
			if (g.x >= lo.x && g.y >= lo.y && g.x <= hi.x && g.y <= hi.y) {
				vec2 dv = (g - c);
				float len = length(dv);
				vec2 np = c + dv / max(len, 0.0000001) * s;
				best = min(best, length((g - np) * to_px));
			}
			vec2 e0 = sq.xy;
			vec2 e1 = sq.xy + sq.zw;
			vec2 gp = g * to_px;
			rect_d = min(rect_d, seg(gp, e0 * to_px, vec2(e1.x, e0.y) * to_px));
			rect_d = min(rect_d, seg(gp, vec2(e1.x, e0.y) * to_px, e1 * to_px));
			rect_d = min(rect_d, seg(gp, e1 * to_px, vec2(e0.x, e1.y) * to_px));
			rect_d = min(rect_d, seg(gp, vec2(e0.x, e1.y) * to_px, e0 * to_px));
		}
		main_l = line_cov(best, hw);
		faint = line_cov(rect_d, hw * 0.7);
	} else {
		vec2 px = UV * res;
		vec2 tl = vec2(0.0);
		vec2 tr = vec2(res.x, 0.0);
		vec2 br = res;
		vec2 bl = vec2(0.0, res.y);
		bool flip = turn == 1 || turn == 3;
		vec2 da = flip ? tr : tl;
		vec2 db = flip ? bl : br;
		vec2 oa = flip ? tl : tr;
		vec2 ob = flip ? br : bl;
		if (guide == 2) {
			main_l = max(line_cov(seg(px, tl, br), hw), line_cov(seg(px, tr, bl), hw));
			float m = min(res.x, res.y);
			faint = max(faint, line_cov(seg(px, tl, tl + vec2(m)), hw));
			faint = max(faint, line_cov(seg(px, tr, tr + vec2(-m, m)), hw));
			faint = max(faint, line_cov(seg(px, br, br - vec2(m)), hw));
			faint = max(faint, line_cov(seg(px, bl, bl + vec2(m, -m)), hw));
		} else if (guide == 3) {
			main_l = line_cov(seg(px, da, db), hw);
			main_l = max(main_l, line_cov(seg(px, oa, foot(oa, da, db)), hw));
			main_l = max(main_l, line_cov(seg(px, ob, foot(ob, da, db)), hw));
		} else {
			main_l = max(line_cov(seg(px, tl, br), hw), line_cov(seg(px, tr, bl), hw));
			vec2 corners[4] = vec2[4](tl, tr, br, bl);
			for (int i = 0; i < 4; i++) {
				vec2 k = corners[i];
				vec2 other_a = corners[(i + 1) % 4];
				vec2 other_b = corners[(i + 3) % 4];
				vec2 dir = normalize(foot(k, other_a, other_b) - k);
				faint = max(faint, line_cov(seg(px, k, hit_edge(k, dir, res)), hw));
			}
		}
	}
	float a = max(main_l, faint * clamp(extra, 0.0, 1.0)) * colour.a;
	COLOR = vec4(colour.rgb, 1.0) * a + pic * (1.0 - a);
}
