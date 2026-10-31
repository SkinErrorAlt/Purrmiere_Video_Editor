shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float roughness : hint_range(0.0, 1.0) = 0.6;
uniform float fibres : hint_range(0.0, 1.0) = 0.6;
uniform float edge : hint_range(0.0, 60.0) = 16.0;
uniform vec4 edge_colour : source_color = vec4(0.97, 0.96, 0.92, 1.0);
uniform float curl : hint_range(0.01, 0.2) = 0.07;
uniform float lift : hint_range(0.0, 1.0) = 0.85;
uniform float tilt : hint_range(0.0, 30.0) = 12.0;
uniform float shadow : hint_range(0.0, 1.0) = 0.6;
uniform float tear_speed : hint_range(1.0, 5.0) = 2.5;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.75;
uniform int curve = 2;

float tear_wander(float s) {
	return (tr_fbm(vec2(s * 2.6, 1.3)) - 0.5) * 0.1;
}

float tear_detail(float s) {
	float jag = (tr_noise(vec2(s * 38.0, 7.7)) - 0.5) * 2.0;
	float tooth = (tr_noise(vec2(s * 170.0, 4.1)) - 0.5) * 2.0;
	return 0.014 * jag + 0.005 * tooth;
}

float fibre_length(float s, float amount) {
	float clump = tr_noise(vec2(s * 45.0, 3.1));
	float fine = tr_noise(vec2(s * 210.0, 9.4));
	return (0.0015 + 0.005 * fine + 0.024 * pow(clump, 4.0)) * amount;
}

float ridge(float n) {
	return 1.0 - abs(2.0 * n - 1.0);
}

float fibre_alpha(float s, float u_out, float amount, out float shade) {
	shade = 1.0;
	if (amount <= 0.0) {
		return 0.0;
	}
	float len = max(fibre_length(s, amount), 0.00001);
	float dens = exp(-u_out / len * 1.4);
	float ang1 = (tr_noise(vec2(s * 30.0, 5.5)) - 0.5) * 1.8;
	float ang2 = (tr_noise(vec2(s * 22.0, 1.7)) - 0.5) * 2.6 + 0.5;
	vec2 p = vec2(s, u_out);
	vec2 r1 = tr_rotate(p, ang1);
	vec2 r2 = tr_rotate(p, ang2);
	float st1 = pow(ridge(tr_noise(vec2(r1.x * 55.0, r1.y * 520.0))), 9.0);
	float st2 = pow(ridge(tr_noise(vec2(r2.x * 30.0 + 7.0, r2.y * 260.0))), 6.0);
	float gaps = smoothstep(0.25, 0.6, tr_noise(vec2(s * 120.0, u_out * 300.0 + 2.0)));
	float strands = (0.6 * st1 + 0.5 * st2) * (0.4 + 0.6 * gaps);
	float mat = (1.0 - smoothstep(0.0, len * 0.35, u_out)) * (0.55 + 0.45 * gaps);
	shade = 0.82 + 0.18 * clamp(st1 + st2, 0.0, 1.0);
	return clamp(strands * 2.4 * dens + mat * 0.95, 0.0, 1.0) * clamp(amount * 2.0, 0.0, 1.0);
}

vec3 key_light() {
	return normalize(vec3(-0.35, 0.55, -1.0));
}

float lit(vec3 n) {
	vec3 l = key_light();
	float flat_d = -l.z;
	float d = max(dot(n, l), 0.0);
	float amb = 0.22;
	return mix(1.0, (amb + (1.0 - amb) * d) / (amb + (1.0 - amb) * flat_d), clamp(shading, 0.0, 1.0));
}

vec4 front_face(vec4 pic, float u, float s, float ew, float grain, float edge_on, vec2 ws, float pxw) {
	float has = step(0.000001, ew);
	float near_edge = 1.0 - smoothstep(ew, ew * 3.0 + 0.004, u);
	float fibre_grain = tr_noise(vec2(s * 260.0, u * 900.0)) - 0.5;
	vec4 shaded = tr_shade(pic, 1.0 + grain * has * near_edge * 0.05 * fibre_grain);
	float core_edge = ew * (0.7 + 0.3 * tr_noise(vec2(s * 420.0, u * 50.0 + 3.0)));
	float core = (1.0 - smoothstep(core_edge - 0.0015, core_edge, u)) * has;
	float fibre_tex = 0.88 + 0.12 * tr_noise(vec2(s * 900.0, u * 2400.0));
	vec3 white = edge_colour.rgb * fibre_tex * (1.0 - 0.1 * smoothstep(0.0, max(core_edge, 0.0001), u));
	float lip = 1.0 - smoothstep(0.0, 1.2 * pxw, u);
	white *= 1.0 - 0.4 * edge_on * lip;
	vec4 wc = vec4(clamp(white, 0.0, 1.0) * edge_colour.a, edge_colour.a);
	float rim = smoothstep(core_edge, core_edge + 0.0012, u) * (1.0 - smoothstep(core_edge + 0.0012, core_edge + 0.004, u));
	shaded = tr_shade(shaded, 1.0 - 0.25 * rim * has);
	return mix(shaded, wc, core);
}

vec4 back_face(vec4 pic, float u, float s, float edge_on, vec2 ws, float pxw) {
	vec2 fib_axis = vec2(dot(ws, vec2(0.6, 0.8)), dot(ws, vec2(-0.8, 0.6)));
	float g = 0.97 + 0.03 * (tr_noise(vec2(fib_axis.x * 40.0, fib_axis.y * 260.0)) - 0.5) + 0.03 * (tr_noise(ws * 70.0) - 0.5);
	float show = dot(pic.rgb, vec3(0.3, 0.5, 0.2));
	vec3 back = edge_colour.rgb * g * (0.9 + 0.1 * show);
	float lip = 1.0 - smoothstep(0.0, 1.8 * pxw, u);
	float bright = smoothstep(1.2 * pxw, 2.2 * pxw, u) * (1.0 - smoothstep(2.2 * pxw, 4.0 * pxw, u));
	back *= (1.0 - 0.5 * lip) * (1.0 + 0.06 * bright);
	return vec4(clamp(back, 0.0, 1.0) * edge_colour.a, edge_colour.a);
}

vec2 rot_xz(vec2 v, float ang) {
	float c = cos(ang);
	float s = sin(ang);
	return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

vec4 transition(vec2 uv) {
	float rt = tr_ratio();
	vec2 a = vec2(0.0, -1.0);
	if (direction == 1) {
		a = vec2(1.0, 0.0);
	} else if (direction == 2) {
		a = normalize(vec2(rt, -1.0));
	}
	vec2 nrm = vec2(-a.y, a.x);
	vec2 w = tr_world(uv);
	float s_pix = dot(w, a);
	float x_pix = dot(w, nrm);
	float half_s = abs(a.x) * rt * 0.5 + abs(a.y) * 0.5;
	float half_x = abs(nrm.x) * rt * 0.5 + abs(nrm.y) * 0.5;
	float rough = clamp(roughness, 0.0, 1.0);
	float fa = clamp(fibres, 0.0, 1.0);
	float ew_max = edge * px_scale / max(frame_px.y, 1.0);
	float px = max(frame_px.y, 1.0);
	float pxw = 1.0 / px;
	float tear_time = 1.0 / clamp(tear_speed, 1.0, 5.0);
	float tq = clamp(progress / tear_time, 0.0, 1.0);
	float margin = 0.06;
	float s_tip = mix(-half_s - margin, half_s + margin, tr_ease(tq, 2));
	float pull_start = tear_time * 0.75;
	float q = clamp((progress - pull_start) / max(1.0 - pull_start, 0.0001), 0.0, 1.0);
	int kind = curve == 1 ? 3 : (curve == 2 ? 1 : 0);
	float rad_base = clamp(curl, 0.01, 0.2);
	float jmax = rough * 0.02 + 0.002 + 1.0 / px;
	float fib_max = 0.035 * fa;
	float reach = half_x + rough * 0.07 + ew_max * 1.75 + fib_max + 0.05 + margin;
	float grain = smoothstep(0.0, 0.12, progress);
	float fade_out = 1.0 - smoothstep(0.75, 1.0, progress);
	float fib_grow = smoothstep(0.0, 0.05, progress);
	float side_n = smoothstep(0.25, 0.75, tr_noise(vec2(s_pix * 9.0, 8.8)));
	float dist = tr_camera_distance(lens);
	vec3 dir = normalize(vec3(w, dist));
	float ds = dot(dir.xy, a);
	float dxn = dot(dir.xy, nrm);
	float tilt_q = sin(TR_PI * min(q * 1.6, 1.0) * 0.5);
	vec4 fibre_layer[2];
	float fibre_alpha_v[2];
	vec4 solid_col[2];
	float solid_cov[2];
	float sh = 0.0;
	for (int hside = 0; hside < 2; hside++) {
		float sg = hside == 0 ? 1.0 : -1.0;
		float pull = hside == 0 ? reach * tr_ease(q, kind) : reach * tr_ease(pow(q, 1.25), kind);
		float shear = hside == 0 ? 0.035 : 0.05;
		float phi = radians(clamp(tilt, 0.0, 30.0)) * tilt_q * (hside == 0 ? 1.0 : 0.8) * clamp(lift + 0.3, 0.0, 1.0);
		float pivot_w = -half_x - 0.02 - pull;
		float lift_z = -0.04 * tilt_q * clamp(lift, 0.0, 1.0);
		vec2 o_xz = vec2(-pivot_w, -dist - lift_z);
		vec2 d_xz = vec2(sg * dxn, dir.z);
		o_xz = rot_xz(o_xz, phi);
		d_xz = rot_xz(d_xz, phi);
		float rad = rad_base;
		float ew_side = ew_max * (hside == 0 ? (0.25 + 1.5 * side_n) : (0.25 + 1.5 * (1.0 - side_n)));
		float s_e = s_pix;
		float best_l = 1000000.0;
		float best_xf = 0.0;
		float best_th = 0.0;
		float best_side = 1.0;
		float fib_l = 1000000.0;
		float fib_xf = 0.0;
		float fib_th = 0.0;
		float fib_side = 1.0;
		float t_loc = 0.0;
		float c_line = 0.0;
		float lift_s = 0.0;
		float d_off = 0.0;
		float fib_len = 0.0;
		float torn = 0.0;
		for (int it = 0; it < 2; it++) {
			float open_len = max(s_tip - s_e, 0.0);
			torn = smoothstep(0.0, 0.03, s_tip - s_e);
			d_off = pull + shear * open_len;
			float wander = sg * tear_wander(s_e) * rough;
			t_loc = wander + sg * tear_detail(s_e) * rough;
			lift_s = clamp(0.55 * smoothstep(0.0, 0.35, open_len) + 0.45 * tr_ease(q, 3), 0.0, 1.0) * torn;
			rad = rad_base * (0.8 + 0.4 * tr_noise(vec2(s_e * 3.2, 14.2)));
			float roll = 1.15 * TR_PI * rad * clamp(lift, 0.0, 1.0);
			c_line = wander + jmax - (jmax + roll) * lift_s;
			fib_len = fibre_length(s_e, fa) * 2.6 * torn * fib_grow;
			float lim = t_loc + max(fib_len, 0.5 * pxw);
			best_l = 1000000.0;
			fib_l = 1000000.0;
			float x0 = o_xz.x + pivot_w + d_off;
			float z0 = o_xz.y;
			float dx = d_xz.x;
			float dz = d_xz.y;
			if (abs(dz) > 0.000001) {
				float lf = -z0 / dz;
				float xf = x0 + dx * lf;
				if (lf > 0.0 && xf <= c_line) {
					if (xf <= t_loc + 0.5 * pxw) {
						best_l = lf;
						best_xf = xf;
						best_th = 0.0;
						best_side = 1.0;
					} else if (xf <= lim) {
						fib_l = lf;
						fib_xf = xf;
						fib_th = 0.0;
						fib_side = 1.0;
					}
				}
			}
			float cx0 = x0 - c_line;
			float cz0 = z0 + rad;
			float qa = dx * dx + dz * dz;
			float qb = 2.0 * (cx0 * dx + cz0 * dz);
			float qc = cx0 * cx0 + cz0 * cz0 - rad * rad;
			float disc = qb * qb - 4.0 * qa * qc;
			if (disc >= 0.0) {
				float sq = sqrt(disc);
				for (int k = 0; k < 2; k++) {
					float l = (-qb + (k == 0 ? -sq : sq)) / (2.0 * qa);
					if (l <= 0.0) {
						continue;
					}
					float hx = cx0 + dx * l;
					float hz = cz0 + dz * l;
					float th = atan(hx, hz);
					if (th < -0.5 * TR_PI) {
						th += 2.0 * TR_PI;
					}
					if (th < 0.0) {
						continue;
					}
					float x_on = c_line + rad * th;
					float face = (dx * sin(th) + dz * cos(th)) > 0.0 ? 1.0 : -1.0;
					if (x_on <= t_loc + 0.5 * pxw) {
						if (l < best_l) {
							best_l = l;
							best_xf = x_on;
							best_th = th;
							best_side = face;
						}
					} else if (x_on <= lim && l < fib_l) {
						fib_l = l;
						fib_xf = x_on;
						fib_th = th;
						fib_side = face;
					}
				}
			}
			if (best_l < 100000.0) {
				s_e = ds * best_l;
			}
		}
		vec3 axis_x = vec3(sg * nrm, 0.0);
		vec4 col = vec4(0.0);
		float cov = 0.0;
		if (best_l < 100000.0) {
			float u = t_loc - best_xf;
			cov = clamp(u * px + 0.5, 0.0, 1.0);
			vec2 ws = s_e * a + sg * best_xf * nrm;
			vec4 pic = from_at(tr_frame_uv(ws));
			float edge_on = clamp(abs(sin(best_th)) + sin(phi), 0.0, 1.0);
			vec2 n_loc = rot_xz(vec2(sin(best_th), cos(best_th)), -phi);
			vec3 n_out = n_loc.x * axis_x + vec3(0.0, 0.0, n_loc.y);
			vec3 n_vis = best_side > 0.0 ? -n_out : n_out;
			float light = lit(n_vis);
			if (best_side > 0.0) {
				col = front_face(pic, max(u, 0.0), s_e, ew_side * torn * fib_grow, grain, edge_on, ws, pxw);
				if (best_th <= 0.0) {
					float gap_c = max(c_line - best_xf, 0.0);
					float ao = 0.45 * exp(-gap_c / (rad * 0.35)) + 0.2 * exp(-gap_c / (rad * 1.5));
					col = tr_shade(col, 1.0 - ao * lift_s);
				} else {
					float open_up = smoothstep(0.0, 0.65 * TR_PI, best_th);
					col = tr_shade(col, 1.0 - 0.65 * lift_s * (1.0 - 0.75 * open_up));
				}
			} else {
				col = back_face(pic, max(u, 0.0), s_e, edge_on, ws, pxw);
				float crown = abs(cos(best_th));
				col = tr_shade(col, 0.82 + 0.18 * crown);
			}
			col = tr_shade(col, light);
		}
		solid_col[hside] = col;
		solid_cov[hside] = cov;
		float fa_here = 0.0;
		vec4 fcol = vec4(0.0);
		if (fib_l < best_l && fib_len > 0.0) {
			float fshade;
			fa_here = fibre_alpha(s_e, fib_xf - t_loc, fa, fshade) * torn * fib_grow;
			vec2 n_loc = rot_xz(vec2(sin(fib_th), cos(fib_th)), -phi);
			vec3 n_out = n_loc.x * axis_x + vec3(0.0, 0.0, n_loc.y);
			vec3 fc = edge_colour.rgb * fshade * lit(fib_side > 0.0 ? -n_out : n_out);
			fcol = vec4(clamp(fc, 0.0, 1.0) * edge_colour.a, edge_colour.a);
		}
		fibre_layer[hside] = fcol;
		fibre_alpha_v[hside] = fa_here;
		float th_max = max((t_loc - c_line) / rad, 0.0);
		float foot = th_max > 0.0 ? c_line + rad * sin(min(th_max, 0.5 * TR_PI)) : t_loc;
		float delta = max(foot - d_off - pivot_w, 0.0);
		float tilt_h = delta * sin(phi) - lift_z;
		float foot_w = pivot_w + delta * cos(phi);
		float roll_h = rad * (1.0 - cos(min(th_max, TR_PI)));
		float height = roll_h + tilt_h;
		float gap = max(sg * x_pix - foot_w, 0.0);
		float spread_w = 0.002 + 0.4 * roll_h + 0.1 * tilt_h;
		float strength = 0.65 - 0.25 * smoothstep(0.0, 0.25, height);
		float fib_shadow = fibre_alpha_v[hside] * 0.25 * clamp(shadow, 0.0, 1.0);
		sh = max(sh, clamp(shadow, 0.0, 1.0) * strength * exp(-gap / spread_w) * torn * grain * fade_out + fib_shadow * fade_out);
	}
	float cov_l = solid_cov[0];
	float cov_r = solid_cov[1];
	vec4 under = tr_shade(to_at(uv), 1.0 - clamp(sh, 0.0, 0.9));
	vec4 res = solid_col[0] * cov_l + solid_col[1] * cov_r + under * max(1.0 - cov_l - cov_r, 0.0);
	res = mix(res, fibre_layer[0], fibre_alpha_v[0]);
	res = mix(res, fibre_layer[1], fibre_alpha_v[1]);
	return res;
}

void fragment() {
	COLOR = transition(UV);
}
