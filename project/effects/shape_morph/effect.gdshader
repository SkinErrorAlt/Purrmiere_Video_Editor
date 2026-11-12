shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1920.0, 1080.0);
uniform float clip_time = 0.0;
uniform bool out_depth = false;

uniform float morph : hint_range(0.0, 4.0) = 1.0;
uniform int path : hint_range(0, 4) = 0;
uniform float scale : hint_range(0.05, 4.0) = 1.0;
uniform float turn : hint_range(-1080.0, 1080.0) = 0.0;
uniform float spin : hint_range(-720.0, 720.0) = 0.0;
uniform float tilt : hint_range(-90.0, 90.0) = 0.0;
uniform float roll : hint_range(-180.0, 180.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float distance : hint_range(0.3, 20.0) = 1.3737;
uniform float fov : hint_range(5.0, 120.0) = 40.0;
uniform float light_angle : hint_range(-180.0, 180.0) = -40.0;
uniform float light_height : hint_range(-90.0, 90.0) = 40.0;
uniform float ambient : hint_range(0.0, 2.0) = 0.32;
uniform float diffuse : hint_range(0.0, 2.0) = 0.85;
uniform float specular : hint_range(0.0, 2.0) = 0.35;
uniform float gloss : hint_range(1.0, 256.0) = 40.0;
uniform float shadows : hint_range(0.0, 1.0) = 0.85;
uniform float occlusion : hint_range(0.0, 1.0) = 0.6;
uniform int back_mode : hint_range(0, 2) = 0;
uniform vec4 back_colour : source_color = vec4(0.93, 0.91, 0.87, 1.0);


struct Shape {
	float kr;
	float half_az;
	bool closed_az;
	float kp;
	bool closed_p;
	float s0;
	float s1;
	float sa;
	float ca;
	float zp;
	float rrev;
	float bound;
	float sc;
};

float ease(float x) {
	float t = clamp(x, 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

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

float profile_r(Shape S, float s) {
	if (S.kp > 0.001) {
		return S.rrev + (cos(S.kp * s - atan(S.sa, S.ca)) - S.ca) / S.kp;
	}
	return S.rrev + s * S.sa;
}

Shape make_shape(float m, float a, float sc) {
	float w = a * sc;
	float h = sc;
	float rs = 0.40 * sc;
	float rc = 0.27 * sc;
	float hc = 0.88 * sc;
	float rb = 0.37 * sc;
	float hn = 0.86 * sc;
	float tr = 0.29 * sc;
	float tt = 0.135 * sc;
	float ln = sqrt(rb * rb + hn * hn);
	float alc = atan(rb, hn);
	Shape S;
	S.sc = sc;
	S.closed_az = true;
	S.closed_p = false;
	float al = 0.0;
	float hl = 0.5 * h;
	float th = TAU;
	float zp = rs;
	float rrev = rs;
	float kp = 0.0;
	if (path >= 1) {
		float c = ease(min(m, 1.0));
		float rt = rs;
		float kt = 1.0 / rs;
		float at = 0.0;
		float ht = 0.5 * PI * rs;
		if (path == 2) {
			rt = rc;
			kt = 0.0;
			ht = 0.5 * hc;
		} else if (path == 3) {
			rt = 0.5 * rb;
			kt = 0.0;
			at = alc;
			ht = 0.5 * ln;
		} else if (path == 4) {
			rt = tr + tt;
			kt = 1.0 / tt;
			ht = PI * tt;
		}
		th = TAU * c;
		float weff = mix(w, TAU * rt, c);
		float kr = max(th / weff, 0.0001);
		hl = mix(0.5 * h, ht, c);
		kp = kt * c;
		al = at * c;
		rrev = 1.0 / kr;
		S.closed_az = c >= 0.9999;
		S.closed_p = path == 4 && c >= 0.9999;
		S.half_az = 0.5 * weff * kr;
		S.kp = kp;
		S.sa = sin(al);
		S.ca = cos(al);
		S.rrev = rrev;
		float rmin = min(profile_r(S, -hl), profile_r(S, hl));
		if (kp > 0.001) {
			float lo = -kp * hl - al;
			float hi = kp * hl - al;
			if (lo <= -PI || hi >= PI) {
				rmin = rrev + (-1.0 - S.ca) / kp;
			}
		}
		if (rmin < 0.0) {
			rrev -= rmin;
			S.half_az = min(0.5 * weff / rrev, PI);
		}
		zp = min(rrev, rt);
		S.bound = zp + sqrt(0.25 * weff * weff + hl * hl) + 0.02 * sc;
		S.rrev = rrev;
		S.kr = 1.0 / rrev;
		S.s0 = -hl;
		S.s1 = hl;
		S.zp = zp;
		return S;
	}
	if (m <= 1.0) {
		float c = ease(m);
		th = TAU * c;
		float weff = mix(w, TAU * rs, c);
		float kr = max(th / weff, 0.0001);
		float heff = mix(h, PI * rs, c);
		hl = 0.5 * heff;
		kp = PI * c / heff;
		rrev = 1.0 / kr;
		zp = min(rrev, rs);
		S.closed_az = c >= 0.9999;
		S.half_az = 0.5 * weff * kr;
		S.bound = zp + sqrt(0.25 * weff * weff + hl * hl) + 0.02 * sc;
	} else if (m <= 2.0) {
		float c = ease(m - 1.0);
		rrev = mix(rs, rc, c);
		hl = mix(0.5 * PI * rs, 0.5 * hc, c);
		kp = 0.5 * PI * (1.0 - c) / hl;
	} else if (m <= 3.0) {
		float c = ease(m - 2.0);
		al = alc * c;
		rrev = mix(rc, 0.5 * rb, c);
		hl = mix(0.5 * hc, 0.5 * ln, c);
	} else {
		float c = ease(m - 3.0);
		float c2 = 1.0 - c;
		al = alc * c2 * c2;
		hl = mix(0.5 * ln, PI * tt, c);
		kp = PI * c / hl;
		rrev = mix(0.5 * rb, tr + tt, sqrt(c));
		S.closed_p = c >= 0.9999;
	}
	S.kp = kp;
	S.sa = sin(al);
	S.ca = cos(al);
	S.s0 = -hl;
	S.s1 = hl;
	S.rrev = rrev;
	if (m > 1.0) {
		float rmin = min(profile_r(S, -hl), profile_r(S, hl));
		if (kp > 0.001) {
			float lo = -kp * hl - al;
			float hi = kp * hl - al;
			if (lo <= -PI || hi >= PI) {
				rmin = rrev + (-1.0 - S.ca) / kp;
			}
		}
		if (rmin < 0.0) {
			rrev -= rmin;
		}
		S.rrev = rrev;
		S.kr = 1.0 / rrev;
		S.half_az = PI;
		zp = rrev;
		S.bound = rrev + hl + 0.02 * sc;
	} else {
		S.kr = 1.0 / rrev;
	}
	S.zp = zp;
	return S;
}

float surf(Shape S, vec3 p, out vec3 info, out vec3 nrm) {
	float x = p.x;
	float dz = p.z + S.zp;
	float q = 1.0 - S.kr * dz;
	float phi = atan(S.kr * x, q);
	float krr = sqrt(S.kr * S.kr * x * x + q * q);
	float dr = (S.kr * (x * x + dz * dz) - 2.0 * dz) / (1.0 + krr);
	float outd = 0.0;
	float phic = phi;
	if (!S.closed_az) {
		float ex = abs(phi) - S.half_az;
		if (ex > 0.0) {
			phic = sign(phi) * S.half_az;
			float se = sin(ex);
			float h2 = sin(0.5 * ex);
			float drp = dr * cos(ex) - 2.0 * h2 * h2 / S.kr;
			outd = se / S.kr + dr * se;
			dr = drp;
		}
	}
	vec2 lp = vec2(dr, p.y);
	float ta = dot(lp, vec2(S.sa, S.ca));
	float tb = dot(lp, vec2(-S.ca, S.sa));
	float sp;
	vec2 near;
	if (S.kp > 0.001) {
		float rho = 1.0 / S.kp;
		float psi = atan(ta, rho - tb);
		if (!S.closed_p) {
			psi = clamp(psi, S.kp * S.s0, S.kp * S.s1);
		}
		float hh = sin(0.5 * psi);
		near = vec2(sin(psi), 2.0 * hh * hh) * rho;
		sp = psi * rho;
	} else {
		sp = clamp(ta, S.s0, S.s1);
		near = vec2(sp, 0.0);
	}
	float d2 = length(vec2(ta, tb) - near);
	float u = S.closed_az ? fract(0.5 + phic / TAU) : 0.5 + phic / (2.0 * S.half_az);
	float v = (sp - S.s0) / (S.s1 - S.s0);
	float rn = S.rrev + near.x * S.sa - near.y * S.ca;
	info = vec3(u, v, max(rn, 0.0));
	float ang = S.kp * sp;
	vec2 n0 = vec2(-S.ca, S.sa);
	vec2 t0 = vec2(S.sa, S.ca);
	vec2 nout = -(n0 * cos(ang) - t0 * sin(ang));
	nrm = normalize(vec3(nout.x * sin(phic), nout.y, -nout.x * cos(phic)));
	return sqrt(d2 * d2 + outd * outd);
}

float dist(Shape S, vec3 p) {
	vec3 i;
	vec3 n;
	return surf(S, p, i, n);
}

float march(Shape S, vec3 ro, vec3 rd, float t, float tend, float pk, out float nmt, out float nmd) {
	nmt = -1.0;
	nmd = 1.0;
	float ct = -1.0;
	float cd = 1e9;
	for (int i = 0; i < 110; i++) {
		if (t > tend) {
			break;
		}
		float d = dist(S, ro + rd * t);
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
		t += max(d * 0.9, 0.2 * pw);
	}
	if (ct > 0.0 && nmt < 0.0) {
		nmt = ct;
		nmd = cd / max(ct * pk, 1e-6);
	}
	return -1.0;
}

float refine(Shape S, vec3 ro, vec3 rd, float t) {
	for (int k = 0; k < 3; k++) {
		vec3 info;
		vec3 n;
		float d = surf(S, ro + rd * t, info, n);
		t += d / max(abs(dot(rd, n)), 0.25);
	}
	return t;
}

float soft_shadow(Shape S, vec3 p, vec3 l) {
	float bb = dot(p, l);
	float cc = dot(p, p) - S.bound * S.bound;
	float disc = bb * bb - cc;
	if (disc <= 0.0) {
		return 1.0;
	}
	float tend = -bb + sqrt(disc);
	float res = 1.0;
	float t = 0.006 * S.sc;
	for (int i = 0; i < 32; i++) {
		if (t > tend) {
			break;
		}
		float h = dist(S, p + l * t);
		res = min(res, 10.0 * h / t);
		if (res < 0.02) {
			break;
		}
		t += clamp(h, 0.008 * S.sc, 0.2 * S.sc);
	}
	return clamp(res, 0.0, 1.0);
}

float ambient_occ(Shape S, vec3 p, vec3 n) {
	float occ = 0.0;
	float w = 1.0;
	for (int i = 1; i <= 5; i++) {
		float hh = 0.03 * S.sc * float(i);
		occ += w * max(hh - dist(S, p + n * hh), 0.0);
		w *= 0.65;
	}
	return clamp(1.0 - occ * 9.0 / S.sc, 0.0, 1.0);
}

vec4 pic(sampler2D tex, vec2 uv, float fp) {
	vec4 c = texture(tex, uv);
	if (fp > 1.4) {
		vec2 o = vec2(min(fp, 10.0) * 0.5) / tex_size;
		c = 0.2 * c + 0.2 * (texture(tex, uv + o * vec2(0.25, 0.75)) + texture(tex, uv + o * vec2(-0.75, 0.25)) + texture(tex, uv + o * vec2(-0.25, -0.75)) + texture(tex, uv + o * vec2(0.75, -0.25)));
	}
	return c;
}

vec4 shade(Shape S, sampler2D tex, vec3 p, vec3 rd, float pw, vec3 l, float ref) {
	vec3 info;
	vec3 n;
	surf(S, p, info, n);
	bool front = dot(n, rd) < 0.0;
	vec3 ns = front ? n : -n;
	float az_len = 2.0 * S.half_az * max(info.z, 0.0005);
	float tu = tex_size.x / max(az_len, 0.0005);
	float tv = tex_size.y / max(S.s1 - S.s0, 0.0005);
	float slant = max(abs(dot(ns, rd)), 0.15);
	float fp = pw * max(tu, tv) / sqrt(slant);
	vec4 base = pic(tex, info.xy, fp);
	if (!front) {
		if (back_mode == 1) {
			base = back_colour * base.a;
		} else if (back_mode == 2) {
			vec3 through = mix(back_colour.rgb, base.rgb / max(base.a, 0.0001), 0.22);
			base = vec4(through * back_colour.rgb * 1.05, 1.0) * base.a;
		}
	}
	vec3 pp = p + ns * max(0.6 * pw, 0.0015 * S.sc);
	float ndl = dot(ns, l);
	float sh = 0.0;
	if (ndl > 0.0) {
		sh = shadows > 0.001 ? mix(1.0, soft_shadow(S, pp, l), shadows) : 1.0;
	}
	float ao = occlusion > 0.001 ? mix(1.0, ambient_occ(S, pp, ns), occlusion) : 1.0;
	float lit = (ambient * ao + diffuse * max(ndl, 0.0) * sh) / ref;
	vec3 hv = normalize(l - rd);
	float sp = specular * max(pow(max(dot(ns, hv), 0.0), gloss) - pow(max(-hv.z, 0.0), gloss), 0.0) * sh;
	return vec4(base.rgb * lit + vec3(sp) * base.a, base.a);
}

void fragment() {
	float a = tex_size.x / max(tex_size.y, 1.0);
	float m = clamp(morph, 0.0, 4.0);
	float sc = max(scale, 0.01);
	float f = 0.5 / tan(radians(clamp(fov, 1.0, 170.0)) * 0.5);
	vec2 s = vec2((UV.x - 0.5) * a, UV.y - 0.5);
	vec3 rdc = normalize(vec3(s, f));
	vec3 roc = vec3(0.0, 0.0, -distance);
	Shape S = make_shape(m, a, sc);
	vec3 pivot = vec3((centre.x - 0.5) * a, centre.y - 0.5, S.zp);
	float tr = radians(turn + spin * clip_time);
	float tx = radians(tilt);
	float tz = radians(roll);
	vec3 ro = rot_y(rot_x(rot_z(roc - pivot, -tz), -tx), -tr);
	vec3 rd = rot_y(rot_x(rot_z(rdc, -tz), -tx), -tr);
	float la = radians(light_angle);
	float lh = radians(light_height);
	vec3 lc = vec3(cos(lh) * sin(la), -cos(lh) * cos(la), -sin(lh));
	vec3 l = rot_y(rot_x(rot_z(lc, -tz), -tx), -tr);
	float ref = max(ambient + diffuse * max(sin(lh), 0.0), 0.05);
	float pk = rdc.z / (f * max(tex_size.y, 1.0));
	float bound = S.bound + 0.01;
	float b = dot(ro, rd);
	float c = dot(ro, ro) - bound * bound;
	float disc = b * b - c;
	vec4 col = vec4(0.0);
	float depth = 0.0;
	float cover = 0.0;
	if (disc > 0.0) {
		float sq = sqrt(disc);
		float t0 = max(-b - sq, 0.0);
		float t1 = -b + sq;
		float nmt;
		float nmd;
		float th = march(S, ro, rd, t0, t1, pk, nmt, nmd);
		if (th > 0.0) {
			th = refine(S, ro, rd, th);
			depth = th * rdc.z;
			cover = 1.0;
			if (!out_depth) {
				vec3 ph = ro + rd * th;
				col = shade(S, TEXTURE, ph, rd, th * pk, l, ref);
				if (col.a < 0.995) {
					float nmt2;
					float nmd2;
					float t2 = march(S, ro, rd, th + 1.2 * th * pk + 0.002 * sc, t1, pk, nmt2, nmd2);
					if (t2 > 0.0) {
						vec4 c2 = shade(S, TEXTURE, ro + rd * t2, rd, t2 * pk, l, ref);
						col += (1.0 - col.a) * c2;
					}
				}
			}
		}
		if (nmt > 0.0) {
			float cov = clamp((1.0 - nmd) / 0.7, 0.0, 1.0);
			if (cover < 0.5) {
				depth = nmt * rdc.z;
			}
			cover = max(cover, cov);
			if (!out_depth && cov > 0.0) {
				vec4 cn = shade(S, TEXTURE, ro + rd * nmt, rd, nmt * pk, l, ref) * cov;
				col = cn + (1.0 - cn.a) * col;
			}
		}
	}
	if (out_depth) {
		float d01 = clamp(depth / 32.0, 0.0, 1.0) * 255.0;
		COLOR = vec4(floor(d01) / 255.0, fract(d01), cover, 1.0);
	} else {
		COLOR = clamp(col, 0.0, 1.0);
	}
}
