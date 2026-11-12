shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1920.0, 1080.0);
uniform float px_scale = 1.0;
uniform bool out_depth = false;

uniform float fold : hint_range(0.0, 1.0) = 0.6;
uniform float columns : hint_range(2.0, 60.0) = 10.0;
uniform float rows : hint_range(1.0, 40.0) = 5.0;
uniform float slant : hint_range(40.0, 88.0) = 72.0;
uniform float crease : hint_range(0.0, 20.0) = 2.0;
uniform float tilt : hint_range(-89.0, 89.0) = 0.0;
uniform float swivel : hint_range(-89.0, 89.0) = 0.0;
uniform float rotation : hint_range(-180.0, 180.0) = 0.0;
uniform vec2 offset = vec2(0.0, 0.0);
uniform float scale : hint_range(0.05, 4.0) = 1.0;
uniform float distance : hint_range(0.3, 20.0) = 1.3737;
uniform float fov : hint_range(5.0, 120.0) = 40.0;
uniform float light_angle : hint_range(-180.0, 180.0) = -40.0;
uniform float light_height : hint_range(-90.0, 90.0) = 35.0;
uniform float ambient : hint_range(0.0, 2.0) = 0.35;
uniform float diffuse : hint_range(0.0, 2.0) = 0.8;
uniform float specular : hint_range(0.0, 2.0) = 0.15;
uniform float gloss : hint_range(1.0, 256.0) = 24.0;
uniform float shadows : hint_range(0.0, 1.0) = 0.8;
uniform float occlusion : hint_range(0.0, 1.0) = 0.5;
uniform float floor_shadow : hint_range(0.0, 1.0) = 0.6;

struct Fold {
	float a;
	float h;
	float s;
	float v;
	float l;
	float v0;
	float l0;
	float w;
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

float tri(float t) {
	return 1.0 - abs(mod(t, 2.0) - 1.0);
}

vec2 cell_pq(Fold F, vec2 xy) {
	float q = xy.y / F.l;
	float p = (xy.x - F.v * tri(q)) / F.s;
	return vec2(p, q);
}

vec3 facet_plane(Fold F, float i, float j) {
	float sg = mod(i, 2.0) < 0.5 ? 1.0 : -1.0;
	float ci = mod(i, 2.0) < 0.5 ? -i : 1.0 + i;
	float tg = mod(j, 2.0) < 0.5 ? 1.0 : -1.0;
	float cj = mod(j, 2.0) < 0.5 ? -j : 1.0 + j;
	float px = 1.0 / F.s;
	float py = -F.v * tg / (F.l * F.s);
	float p0 = -F.v * cj / F.s;
	return vec3(-F.h * sg * px, -F.h * sg * py, -F.h * (sg * p0 + ci));
}

vec2 flat_xy(Fold F, vec2 pq) {
	return vec2(pq.x * F.a + F.v0 * tri(pq.y), pq.y * F.l0);
}

bool on_paper(Fold F, vec2 pq, float asp) {
	vec2 f = flat_xy(F, pq);
	return abs(f.x) <= 0.5 * asp && abs(f.y) <= 0.5;
}

float trace(Fold F, vec3 o, vec3 d, float t0, float t1, float asp, bool any_hit, out vec2 hit_pq, out float soft) {
	soft = 1.0;
	hit_pq = vec2(0.0);
	float t = t0;
	for (int it = 0; it < 64; it++) {
		if (t >= t1) {
			break;
		}
		vec3 r = o + d * t;
		vec2 pq = cell_pq(F, r.xy);
		float i = floor(pq.x);
		float j = floor(pq.y);
		float tg = mod(j, 2.0) < 0.5 ? 1.0 : -1.0;
		float cj = mod(j, 2.0) < 0.5 ? -j : 1.0 + j;
		float dq = d.y / F.l;
		float dp = (d.x - F.v * tg * dq) / F.s;
		float te = t1;
		if (dq > 1e-9) {
			te = min(te, t + (j + 1.0 - pq.y) / dq);
		} else if (dq < -1e-9) {
			te = min(te, t + (j - pq.y) / dq);
		}
		if (dp > 1e-9) {
			te = min(te, t + (i + 1.0 - pq.x) / dp);
		} else if (dp < -1e-9) {
			te = min(te, t + (i - pq.x) / dp);
		}
		vec3 pl = facet_plane(F, i, j);
		float g0 = r.z - (pl.x * r.x + pl.y * r.y + pl.z);
		float gd = d.z - (pl.x * d.x + pl.y * d.y);
		vec3 re = o + d * te;
		float ge = re.z - (pl.x * re.x + pl.y * re.y + pl.z);
		if (any_hit && ge < 0.0 && on_paper(F, clamp(cell_pq(F, re.xy), vec2(i, j) + 1e-4, vec2(i, j) + 1.0 - 1e-4), asp)) {
			soft = min(soft, -ge * 40.0 / max(te, 0.001));
		}
		bool crosses = any_hit ? ((g0 <= 0.0) != (ge <= 0.0)) : (g0 <= 0.0 && ge >= 0.0);
		if (crosses && abs(gd) > 1e-9) {
			float th = t - g0 / gd;
			vec2 hp = cell_pq(F, (o + d * th).xy);
			hp = clamp(hp, vec2(i, j) + 1e-4, vec2(i, j) + 1.0 - 1e-4);
			if (on_paper(F, hp, asp)) {
				hit_pq = hp;
				if (any_hit) {
					soft = 0.0;
				}
				return th;
			}
		}
		t = te + 1e-5;
	}
	return -1.0;
}

vec3 facet_normal(Fold F, float i, float j) {
	vec3 pl = facet_plane(F, i, j);
	return normalize(vec3(pl.x, pl.y, -1.0));
}

vec4 pic(sampler2D tex, vec2 uv, float fp) {
	vec4 c = texture(tex, uv);
	if (fp > 1.4) {
		vec2 o = vec2(min(fp, 10.0) * 0.5) / tex_size;
		c = 0.2 * c + 0.2 * (texture(tex, uv + o * vec2(0.25, 0.75)) + texture(tex, uv + o * vec2(-0.75, 0.25)) + texture(tex, uv + o * vec2(-0.25, -0.75)) + texture(tex, uv + o * vec2(0.75, -0.25)));
	}
	return c;
}

float light_facet(vec3 n, vec3 l, vec3 rd, float sh, float ao, float ref, out float sp) {
	float ndl = dot(n, l);
	vec3 hv = normalize(l - rd);
	sp = specular * max(pow(max(dot(n, hv), 0.0), gloss) - pow(max(-hv.z, 0.0), gloss), 0.0) * sh;
	return (ambient * ao + diffuse * max(ndl, 0.0) * sh) / ref;
}

void fragment() {
	float asp = tex_size.x / max(tex_size.y, 1.0);
	float sc = max(scale, 0.01);
	float f = 0.5 / tan(radians(clamp(fov, 1.0, 170.0)) * 0.5);
	vec2 sp2 = vec2((UV.x - 0.5) * asp, UV.y - 0.5);
	vec3 rdc = normalize(vec3(sp2, f));
	vec3 roc = vec3(0.0, 0.0, -distance);
	vec3 org = vec3(offset.x * asp, offset.y, 0.0);
	float tx = radians(tilt);
	float ty = radians(swivel);
	float tz = radians(rotation);
	vec3 ro = rot_x(rot_y(rot_z(roc - org, -tz), -ty), -tx) / sc;
	vec3 rd = rot_x(rot_y(rot_z(rdc, -tz), -ty), -tx);
	float la = radians(light_angle);
	float lh = radians(light_height);
	vec3 lc = vec3(cos(lh) * sin(la), -cos(lh) * cos(la), -sin(lh));
	vec3 l = rot_x(rot_y(rot_z(lc, -tz), -ty), -tx);
	float ref = max(ambient + diffuse * max(sin(lh), 0.0), 0.05);
	float pk = rdc.z / (f * max(tex_size.y, 1.0));
	Fold F;
	F.w = asp;
	F.a = asp / max(columns, 1.0);
	F.l0 = 1.0 / max(rows, 1.0);
	float gam = radians(clamp(slant, 1.0, 89.0));
	float b = F.l0 / sin(gam);
	F.v0 = b * cos(gam);
	F.h = clamp(fold, 0.0, 1.0) * 0.97 * F.a * sin(gam);
	F.s = sqrt(max(F.a * F.a - F.h * F.h, 1e-8));
	F.v = F.a * F.v0 / F.s;
	F.l = sqrt(max(b * b - F.v * F.v, 1e-8));
	vec4 col = vec4(0.0);
	float depth = 0.0;
	float cover = 0.0;
	if (abs(rd.z) > 1e-6) {
		float t_top = (-F.h - 1e-4 - ro.z) / rd.z;
		float t_base = (1e-4 - ro.z) / rd.z;
		float ta = max(min(t_top, t_base), 0.0);
		float tb = max(t_top, t_base);
		vec2 pq;
		float soft;
		float th = tb > 0.0 ? trace(F, ro, rd, ta, tb, asp, false, pq, soft) : -1.0;
		if (th > 0.0) {
			depth = th * sc * rdc.z;
			cover = 1.0;
			if (!out_depth) {
				vec3 p = ro + rd * th;
				vec2 fxy = flat_xy(F, pq);
				vec2 uv = vec2(fxy.x / asp + 0.5, fxy.y + 0.5);
				float pw = th * pk;
				vec3 n = facet_normal(F, floor(pq.x), floor(pq.y));
				float fp = pw * tex_size.y / max(abs(dot(n, rd)), 0.2);
				vec4 base = pic(TEXTURE, uv, fp);
				float inside = min(0.5 * asp - abs(fxy.x), 0.5 - abs(fxy.y));
				base *= clamp(inside / max(pw, 1e-6) + 0.5, 0.0, 1.0);
				float sh = 1.0;
				if (shadows > 0.001 && F.h > 1e-5 && dot(n, l) > 0.0 && l.z < -1e-4) {
					vec2 spq;
					float ssoft;
					float tmax = (-F.h - 1e-4 - p.z) / l.z;
					float ts = trace(F, p + n * 0.0004, l, 0.0005, max(tmax, 0.0005), asp, true, spq, ssoft);
					float vis = ts > 0.0 ? 0.0 : clamp(ssoft, 0.0, 1.0);
					sh = mix(1.0, vis, shadows);
				}
				float fi = fract(pq.x);
				float fj = fract(pq.y);
				float tp = tri(pq.x);
				float depth01 = F.h / max(F.s + F.h, 1e-5);
				float ao = 1.0 - occlusion * depth01 * pow(1.0 - tp, 2.0) * 0.9;
				float spv;
				float lit = light_facet(n, l, rd, sh, ao, ref, spv);
				float wcr = max(crease * px_scale, 0.75) * pw;
				float dpx = min(fi, 1.0 - fi) * F.s;
				float dqy = min(fj, 1.0 - fj) * F.l * 0.9;
				if (F.h > 1e-5) {
					float ip = fi < 0.5 ? floor(pq.x) - 1.0 : floor(pq.x) + 1.0;
					float jq = fj < 0.5 ? floor(pq.y) - 1.0 : floor(pq.y) + 1.0;
					float wp = clamp(0.5 - dpx / (2.0 * wcr), 0.0, 0.5);
					float wq = clamp(0.5 - dqy / (2.0 * wcr), 0.0, 0.5);
					float sp1;
					float sp2v;
					float lit_p = light_facet(facet_normal(F, ip, floor(pq.y)), l, rd, sh, ao, ref, sp1);
					float lit_q = light_facet(facet_normal(F, floor(pq.x), jq), l, rd, sh, ao, ref, sp2v);
					lit = mix(mix(lit, lit_p, wp), lit_q, wq);
					spv = mix(mix(spv, sp1, wp), sp2v, wq);
				}
				float flat_mix = smoothstep(0.0, 0.002, F.h);
				col = vec4(base.rgb * mix(1.0, lit, flat_mix) + vec3(spv * flat_mix) * base.a, base.a);
			}
		}
		if (!out_depth && floor_shadow > 0.001 && col.a < 0.995 && F.h > 1e-5 && t_base > 0.0 && l.z < -1e-4) {
			vec3 fpnt = ro + rd * t_base;
			vec2 spq;
			float ssoft;
			float tmax = (-F.h - 1e-4 - fpnt.z) / l.z;
			float ts = trace(F, fpnt, l, 0.0005, max(tmax, 0.0005), asp, true, spq, ssoft);
			float vis = ts > 0.0 ? 0.0 : clamp(ssoft, 0.0, 1.0);
			col += (1.0 - col.a) * vec4(0.0, 0.0, 0.0, floor_shadow * (1.0 - vis));
		}
	}
	if (out_depth) {
		float d01 = clamp(depth / 32.0, 0.0, 1.0) * 255.0;
		COLOR = vec4(floor(d01) / 255.0, fract(d01), cover, 1.0);
	} else {
		COLOR = clamp(col, 0.0, 1.0);
	}
}
