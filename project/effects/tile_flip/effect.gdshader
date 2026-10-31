shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.1, 3.0) = 0.8;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int across : hint_range(1, 32) = 8;
uniform int down : hint_range(1, 24) = 5;
uniform int axis : hint_range(0, 1) = 0;
uniform int order : hint_range(0, 2) = 0;
uniform float angle : hint_range(-180.0, 180.0) = 90.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float spread : hint_range(0.0, 0.9) = 0.6;
uniform float perspective : hint_range(0.0, 1.0) = 0.5;
uniform float shade : hint_range(0.0, 1.0) = 0.5;
uniform int seed : hint_range(0, 9999) = 0;

float trans_amount(out bool is_in) {
	float d = max(duration, 0.01);
	if (when == 3) {
		is_in = false;
		return clamp(progress, 0.0, 1.0);
	}
	float a_in = 0.0;
	float a_out = 0.0;
	if (when == 0 || when == 1) {
		a_in = clamp(1.0 - clip_time / d, 0.0, 1.0);
	}
	if (when == 0 || when == 2) {
		a_out = clamp(1.0 - (clip_duration - clip_time) / d, 0.0, 1.0);
	}
	is_in = a_in >= a_out;
	return max(a_in, a_out);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_in = false;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float asp = sz.x / sz.y;
		vec2 n = vec2(float(clamp(across, 1, 32)), float(clamp(down, 1, 24)));
		vec2 cell = min(floor(UV * n), n - 1.0);
		vec2 cc = (cell + 0.5) / n;
		float o = 0.0;
		if (order == 0) {
			float rad = radians(angle);
			vec2 dir = vec2(sin(rad), -cos(rad));
			vec2 half_cell = 0.5 / n;
			vec2 lo = (half_cell - 0.5) * vec2(asp, 1.0);
			float ext = abs(dir.x) * abs(lo.x) + abs(dir.y) * abs(lo.y);
			o = clamp(dot((cc - 0.5) * vec2(asp, 1.0), dir) / max(ext, 0.0001) * 0.5 + 0.5, 0.0, 1.0);
		} else if (order == 1) {
			vec2 ctr = clamp(centre, vec2(0.0), vec2(1.0));
			float far_d = 0.0;
			far_d = max(far_d, length((vec2(0.0, 0.0) - ctr) * vec2(asp, 1.0)));
			far_d = max(far_d, length((vec2(1.0, 0.0) - ctr) * vec2(asp, 1.0)));
			far_d = max(far_d, length((vec2(0.0, 1.0) - ctr) * vec2(asp, 1.0)));
			far_d = max(far_d, length((vec2(1.0, 1.0) - ctr) * vec2(asp, 1.0)));
			o = clamp(length((cc - ctr) * vec2(asp, 1.0)) / max(far_d, 0.0001), 0.0, 1.0);
		} else {
			o = hash12(cell + vec2(float(seed) * 7.13, float(seed) * 3.71 + 1.0));
		}
		float sp = clamp(spread, 0.0, 0.9);
		float oo = is_in ? 1.0 - o : o;
		float local = clamp((g - oo * sp) / max(1.0 - sp, 0.0001), 0.0, 1.0);
		if (local <= 0.0001) {
			COLOR = c;
		} else {
			float cell_asp = (sz.x / n.x) / (sz.y / n.y);
			vec2 s = (UV * n - cell - 0.5) * 2.0 * vec2(cell_asp, 1.0);
			float ex = cell_asp;
			float ey = 1.0;
			if (axis == 1) {
				s = s.yx;
				ex = 1.0;
				ey = cell_asp;
			}
			float e = local * local * (3.0 - 2.0 * local);
			float th = e * 1.5707963 * (is_in ? -1.0 : 1.0);
			float k = 1.0;
			s /= k;
			float dd = mix(12.0, 2.6, clamp(perspective, 0.0, 1.0)) * max(ex, ey);
			float ct = cos(th);
			float sn = sin(th);
			float den = ct * dd - s.x * sn;
			vec4 o_col = vec4(0.0);
			if (den > 0.00001 && ct > 0.0005) {
				float ux = s.x * dd / den;
				float uy = s.y * (dd + ux * sn) / dd;
				vec2 u = vec2(ux, uy);
				float px_s = 2.0 * n.y / sz.y;
				vec2 edge = (vec2(ex, ey) - abs(u)) / px_s / k * vec2(max(ct, 0.02), 1.0);
				float m = clamp(min(edge.x, edge.y) + 0.5, 0.0, 1.0);
				if (m > 0.0) {
					vec2 local_uv = axis == 1 ? vec2(u.y / cell_asp, u.x) : vec2(u.x / cell_asp, u.y);
					vec2 src = (cell + local_uv * 0.5 + 0.5) / n;
					vec4 pic = texture(TEXTURE, clamp(src, vec2(0.0), vec2(1.0)));
					float lit = 1.0 - clamp(shade, 0.0, 1.0) * (1.0 - ct) * 0.8;
					o_col = vec4(pic.rgb * lit, pic.a) * m;
				}
			}
			COLOR = o_col;
		}
	}
}
