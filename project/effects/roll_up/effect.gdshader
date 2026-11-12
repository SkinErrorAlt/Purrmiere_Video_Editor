shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1920.0, 1080.0);
uniform float px_scale = 1.0;
uniform bool out_depth = false;

uniform float rolled : hint_range(0.0, 1.0) = 0.45;
uniform int edge : hint_range(0, 3) = 0;
uniform float core : hint_range(0.002, 0.3) = 0.03;
uniform float thickness : hint_range(1.0, 40.0) = 6.0;
uniform float tilt : hint_range(-89.0, 89.0) = 0.0;
uniform float swivel : hint_range(-89.0, 89.0) = 0.0;
uniform float rotation : hint_range(-180.0, 180.0) = 0.0;
uniform vec2 offset = vec2(0.0, 0.0);
uniform float scale : hint_range(0.05, 4.0) = 1.0;
uniform float distance : hint_range(0.3, 20.0) = 1.3737;
uniform float fov : hint_range(5.0, 120.0) = 40.0;
uniform float light_angle : hint_range(-180.0, 180.0) = -40.0;
uniform float light_height : hint_range(-90.0, 90.0) = 40.0;
uniform float ambient : hint_range(0.0, 2.0) = 0.35;
uniform float diffuse : hint_range(0.0, 2.0) = 0.8;
uniform float specular : hint_range(0.0, 2.0) = 0.12;
uniform float gloss : hint_range(1.0, 256.0) = 18.0;
uniform float shadows : hint_range(0.0, 1.0) = 0.85;
uniform float occlusion : hint_range(0.0, 1.0) = 0.8;
uniform float floor_shadow : hint_range(0.0, 1.0) = 0.6;
uniform int back_mode : hint_range(0, 2) = 2;
uniform vec4 back_colour : source_color = vec4(0.93, 0.91, 0.86, 1.0);

struct Roll {
	float lw;
	float la;
	float ell;
	float rc;
	float g;
	float tmax;
	float big_r;
	float tau;
};

vec3 rot_y(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(v.x * c - v.z * s, v.y, v.x * s + v.z * c);
}

vec3 rot_x(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(v.x, v.y * c + v.z * s, -v.y * s + v.z * c);
}

vec3 rot_z(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(v.x * c - v.y * s, v.x * s + v.y * c, v.z);
}

vec3 to_sheet(vec3 p, float a) {
	float w;
	float c;
	if (edge == 0) {
		w = 0.5 - p.y;
		c = p.x;
	} else if (edge == 1) {
		w = p.y + 0.5;
		c = p.x;
	} else if (edge == 2) {
		w = p.x + 0.5 * a;
		c = p.y;
	} else {
		w = 0.5 * a - p.x;
		c = p.y;
	}
	return vec3(w, -p.z + 0.36 * max(thickness * px_scale / max(tex_size.y, 1.0), 0.0002), c);
}

vec3 dir_sheet(vec3 p) {
	if (edge == 0) {
		return vec3(-p.y, -p.z, p.x);
	} else if (edge == 1) {
		return vec3(p.y, -p.z, p.x);
	} else if (edge == 2) {
		return vec3(p.x, -p.z, p.y);
	}
	return vec3(-p.x, -p.z, p.y);
}

vec2 sheet_uv(float w, float c, float a) {
	if (edge == 0) {
		return vec2(c / a + 0.5, 1.0 - w);
	} else if (edge == 1) {
		return vec2(c / a + 0.5, w);
	} else if (edge == 2) {
		return vec2(w / a, c + 0.5);
	}
	return vec2(1.0 - w / a, c + 0.5);
}

float arc_theta(Roll R, float w) {
	return (-R.rc + sqrt(R.rc * R.rc + R.g * max(w, 0.0) / PI)) * TAU / R.g;
}

float arc_len(Roll R, float th) {
	return R.rc * th + R.g * th * th / (4.0 * PI);
}

float sheet_d2(Roll R, vec2 q, out float wpos, out float side) {
	vec2 fp = vec2(clamp(q.x, R.ell, R.lw), 0.0);
	float best = length(q - fp);
	wpos = fp.x;
	side = q.y >= 0.0 ? 1.0 : -1.0;
	if (R.tmax > 0.0001) {
		vec2 cq = q - vec2(R.ell, R.big_r);
		float rho = length(cq);
		float bq = atan(-cq.x, -cq.y);
		if (bq < 0.0) {
			bq += TAU;
		}
		float base = R.big_r - R.g * bq / TAU;
		float kmax = floor((R.tmax - bq) / TAU);
		float kf = clamp(floor((base - rho) / R.g + 0.5), 0.0, max(kmax, 0.0));
		for (int j = -1; j <= 1; j++) {
			float k = kf + float(j);
			if (k < 0.0 || k > kmax) {
				continue;
			}
			float th = R.tmax - bq - TAU * k;
			float rr = R.rc + R.g * th / TAU;
			float d = abs(rho - rr);
			if (d < best) {
				best = d;
				wpos = arc_len(R, th);
				side = rho < rr ? 1.0 : -1.0;
			}
		}
		vec2 inner = vec2(R.ell, R.big_r) + R.rc * vec2(-sin(R.tmax), -cos(R.tmax));
		float di = length(q - inner);
		if (di < best) {
			best = di;
			wpos = 0.0;
			side = rho < R.rc ? 1.0 : -1.0;
		}
	}
	return best;
}

float sdf(Roll R, vec3 s, out float wpos, out float side, out float endf) {
	float d2 = sheet_d2(R, s.xy, wpos, side) - R.tau;
	float dc = abs(s.z) - 0.5 * R.la;
	vec2 e = vec2(d2, dc);
	endf = dc > d2 ? 1.0 : 0.0;
	return length(max(e, vec2(0.0))) + min(max(d2, dc), 0.0);
}

float dist(Roll R, vec3 s) {
	float w;
	float sd;
	float ef;
	return sdf(R, s, w, sd, ef);
}

float d2_only(Roll R, vec2 q) {
	float w;
	float sd;
	return sheet_d2(R, q, w, sd) - R.tau;
}

float march(Roll R, vec3 ro, vec3 rd, float t, float tend, float pk, out float nmt, out float nmd) {
	nmt = -1.0;
	nmd = 1.0;
	float ct = -1.0;
	float cd = 1e9;
	for (int i = 0; i < 120; i++) {
		if (t > tend) {
			break;
		}
		float d = dist(R, ro + rd * t);
		float pw = t * pk;
		if (d < 0.3 * pw) {
			return t;
		}
		if (d < pw) {
			if (d < cd) {
				cd = d;
				ct = t;
			}
		} else if (ct > 0.0) {
			if (nmt < 0.0) {
				nmt = ct;
				nmd = cd / pw;
			}
			ct = -1.0;
			cd = 1e9;
		}
		t += max(d * 0.9, 0.25 * pw);
	}
	if (ct > 0.0 && nmt < 0.0) {
		nmt = ct;
		nmd = cd / max(ct * pk, 1e-6);
	}
	return -1.0;
}

float soft_shadow(Roll R, vec3 p, vec3 l, float lim) {
	float res = 1.0;
	float t = 2.0 * R.tau;
	for (int i = 0; i < 48; i++) {
		float h = dist(R, p + l * t);
		res = min(res, 14.0 * h / t);
		if (res < 0.02) {
			break;
		}
		t += clamp(h, 0.5 * R.tau, 0.08);
		if (t > lim) {
			break;
		}
	}
	return clamp(res, 0.0, 1.0);
}

float ambient_occ(Roll R, vec3 p, vec3 n) {
	float occ = 0.0;
	float w = 1.0;
	float st = max(R.big_r * 0.3, 2.0 * R.g);
	for (int i = 1; i <= 5; i++) {
		float hh = st * float(i);
		occ += w * max(hh - dist(R, p + n * hh), 0.0);
		w *= 0.6;
	}
	return clamp(1.0 - occ * 2.2 / st, 0.0, 1.0);
}

float refine(Roll R, vec3 ro, vec3 rd, float t) {
	vec3 p = ro + rd * t;
	float e = max(0.25 * R.tau, 0.00005);
	float d0 = d2_only(R, p.xy);
	vec2 g = vec2(d2_only(R, p.xy + vec2(e, 0.0)) - d0, d2_only(R, p.xy + vec2(0.0, e)) - d0);
	float gl = length(g);
	if (gl < 1e-9) {
		return t;
	}
	vec2 n2 = g / gl;
	float c = max(abs(dot(rd.xy, n2)), 0.25);
	for (int k = 0; k < 3; k++) {
		t += d2_only(R, (ro + rd * t).xy) / c;
	}
	return t;
}

vec4 pic(sampler2D tex, vec2 uv, float fp) {
	vec4 c = texture(tex, uv);
	if (fp > 1.4) {
		vec2 o = vec2(min(fp, 10.0) * 0.5) / tex_size;
		c = 0.2 * c + 0.2 * (texture(tex, uv + o * vec2(0.25, 0.75)) + texture(tex, uv + o * vec2(-0.75, 0.25)) + texture(tex, uv + o * vec2(-0.25, -0.75)) + texture(tex, uv + o * vec2(0.75, -0.25)));
	}
	return c;
}

vec4 shade(Roll R, sampler2D tex, vec3 s, vec3 rds, vec3 ls, float pw, float a, float ref) {
	float wpos;
	float side;
	float endf;
	sdf(R, s, wpos, side, endf);
	vec3 n;
	if (endf > 0.5) {
		n = vec3(0.0, 0.0, sign(s.z));
	} else {
		float e = max(0.25 * R.tau, 0.00005);
		float d0 = d2_only(R, s.xy);
		vec2 g = vec2(d2_only(R, s.xy + vec2(e, 0.0)) - d0, d2_only(R, s.xy + vec2(0.0, e)) - d0);
		n = length(g) > 1e-9 ? vec3(normalize(g), 0.0) : vec3(0.0, 1.0, 0.0);
	}
	if (dot(n, rds) > 0.0) {
		n = -n;
	}
	bool pic_side = side > 0.0;
	vec2 uv = sheet_uv(wpos, s.z, a);
	float fp = pw * tex_size.y / max(abs(dot(n, rds)), 0.2);
	vec4 base = pic(tex, uv, fp);
	vec4 backc = back_colour;
	if (back_mode == 0) {
		backc = base;
	} else if (back_mode == 2) {
		vec3 through = mix(back_colour.rgb, base.rgb / max(base.a, 0.0001), 0.2);
		backc = vec4(through * back_colour.rgb * 1.04, 1.0) * base.a;
	} else {
		backc = back_colour * base.a;
	}
	vec4 col = pic_side ? base : backc;
	if (endf > 0.5) {
		col = vec4(back_colour.rgb * 0.82, 1.0) * base.a;
	}
	vec3 pp = s + n * max(0.5 * pw, 0.6 * R.tau);
	float ndl = dot(n, ls);
	float sh = 0.0;
	if (ndl > 0.0) {
		sh = shadows > 0.001 ? mix(1.0, soft_shadow(R, pp, ls, 4.0 * R.big_r + 0.3), shadows) : 1.0;
	}
	float ao = occlusion > 0.001 ? mix(1.0, ambient_occ(R, pp, n), occlusion) : 1.0;
	float lit = (ambient * ao + diffuse * max(ndl, 0.0) * sh * mix(1.0, ao, 0.5)) / ref;
	vec3 hv = normalize(ls - rds);
	float sp = specular * max(pow(max(dot(n, hv), 0.0), gloss) - pow(max(hv.y, 0.0), gloss), 0.0) * sh;
	return vec4(col.rgb * lit + vec3(sp) * col.a, col.a);
}

void fragment() {
	float a = tex_size.x / max(tex_size.y, 1.0);
	float sc = max(scale, 0.01);
	float f = 0.5 / tan(radians(clamp(fov, 1.0, 170.0)) * 0.5);
	vec2 sp = vec2((UV.x - 0.5) * a, UV.y - 0.5);
	vec3 rdc = normalize(vec3(sp, f));
	vec3 roc = vec3(0.0, 0.0, -distance);
	vec3 org = vec3(offset.x * a, offset.y, 0.0);
	float tx = radians(tilt);
	float ty = radians(swivel);
	float tz = radians(rotation);
	vec3 ro = rot_x(rot_y(rot_z(roc - org, -tz), -ty), -tx) / sc;
	vec3 rd = rot_x(rot_y(rot_z(rdc, -tz), -ty), -tx);
	float la = radians(light_angle);
	float lh = radians(light_height);
	vec3 lc = vec3(cos(lh) * sin(la), -cos(lh) * cos(la), -sin(lh));
	vec3 ll = rot_x(rot_y(rot_z(lc, -tz), -ty), -tx);
	float ref = max(ambient + diffuse * max(sin(lh), 0.0), 0.05);
	float pk = rdc.z / (f * max(tex_size.y, 1.0));
	Roll R;
	bool tall = edge >= 2;
	R.lw = tall ? a : 1.0;
	R.la = tall ? 1.0 : a;
	R.g = max(thickness * px_scale / max(tex_size.y, 1.0), 0.0002);
	R.tau = 0.36 * R.g;
	R.rc = max(core, 2.0 * R.g);
	R.ell = clamp(rolled, 0.0, 1.0) * R.lw;
	R.tmax = R.ell > 0.0 ? arc_theta(R, R.ell) : 0.0;
	R.big_r = R.rc + R.g * R.tmax / TAU;
	vec3 ros = to_sheet(ro, a);
	vec3 rds = dir_sheet(rd);
	vec3 lss = dir_sheet(ll);
	vec3 bmin = vec3(-R.tau - 0.01, -R.tau - 0.01, -0.5 * R.la - R.tau - 0.01);
	vec3 bmax = vec3(R.lw + R.tau + 0.01, 2.0 * R.big_r + R.tau + 0.01, 0.5 * R.la + R.tau + 0.01);
	vec3 inv = 1.0 / (abs(rds) + 1e-8) * sign(rds + vec3(1e-9));
	vec3 t_a = (bmin - ros) * inv;
	vec3 t_b = (bmax - ros) * inv;
	vec3 tlo = min(t_a, t_b);
	vec3 thi = max(t_a, t_b);
	float t0 = max(max(max(tlo.x, tlo.y), tlo.z), 0.0);
	float t1 = min(min(thi.x, thi.y), thi.z);
	vec4 col = vec4(0.0);
	float depth = 0.0;
	float cover = 0.0;
	float th = -1.0;
	float nmt = -1.0;
	float nmd = 1.0;
	if (t1 > t0) {
		th = march(R, ros, rds, t0, t1, pk, nmt, nmd);
	}
	float tplane = rds.y != 0.0 ? (-R.tau - ros.y) / rds.y : -1.0;
	if (th > 0.0) {
		th = refine(R, ros, rds, th);
		depth = th * rdc.z * sc;
		cover = 1.0;
		if (!out_depth) {
			col = shade(R, TEXTURE, ros + rds * th, rds, lss, th * pk, a, ref);
			if (col.a < 0.995) {
				float n2t;
				float n2d;
				float t2 = march(R, ros, rds, th + 3.0 * R.tau + th * pk, t1, pk, n2t, n2d);
				if (t2 > 0.0) {
					vec4 c2 = shade(R, TEXTURE, ros + rds * t2, rds, lss, t2 * pk, a, ref);
					col += (1.0 - col.a) * c2;
				} else {
					th = -1.0;
				}
			}
		}
	}
	if (!out_depth && floor_shadow > 0.001 && col.a < 0.995 && tplane > 0.0 && lss.y > 0.0 && R.tmax > 0.0001) {
		vec3 fpnt = ros + rds * tplane;
		float vis = soft_shadow(R, fpnt + vec3(0.0, 0.2 * R.tau, 0.0), lss, 4.0 * R.big_r + 0.3);
		float ao = ambient_occ(R, fpnt, vec3(0.0, 1.0, 0.0));
		float dark = floor_shadow * clamp(1.0 - vis * mix(1.0, ao, 0.7), 0.0, 1.0);
		col += (1.0 - col.a) * vec4(0.0, 0.0, 0.0, dark);
	}
	if (nmt > 0.0) {
		float cov = clamp((1.0 - nmd) / 0.7, 0.0, 1.0);
		if (cover < 0.5) {
			depth = nmt * rdc.z * sc;
		}
		cover = max(cover, cov);
		if (!out_depth && cov > 0.0) {
			vec4 cn = shade(R, TEXTURE, ros + rds * nmt, rds, lss, nmt * pk, a, ref) * cov;
			col = cn + (1.0 - cn.a) * col;
		}
	}
	if (out_depth) {
		float d01 = clamp(depth / 32.0, 0.0, 1.0) * 255.0;
		COLOR = vec4(floor(d01) / 255.0, fract(d01), cover, 1.0);
	} else {
		COLOR = clamp(col, 0.0, 1.0);
	}
}
