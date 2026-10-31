shader_type canvas_item;
render_mode blend_disabled;

uniform float rate : hint_range(0.05, 3.0) = 0.9;
uniform float size : hint_range(20.0, 1500.0) = 300.0;
uniform int stars : hint_range(16, 200) = 90;
uniform int palette : hint_range(0, 3) = 0;
uniform vec4 colour : source_color = vec4(1.0, 0.22, 0.3, 1.0);
uniform int kind : hint_range(0, 4) = 0;
uniform float launch_x : hint_range(0.0, 1.0) = 0.5;
uniform float launch_area : hint_range(0.0, 1.0) = 0.7;
uniform float height : hint_range(0.0, 1.0) = 0.32;
uniform float gravity : hint_range(0.0, 1000.0) = 150.0;
uniform float trail : hint_range(0.0, 2.0) = 0.45;
uniform bool rockets = true;
uniform int seed : hint_range(0, 9999) = 0;
uniform float px_scale = 1.0;
uniform float clip_time;

struct Burst {
	float slot;
	vec4 hb;
	vec4 hc;
	vec4 hd;
	float launch;
	float rise_t;
	int kd;
	vec2 lpos;
	vec2 bpos;
	float scale;
	float a;
	float k;
	float life;
	float tt;
	float pop_end;
	float v0;
	float gk;
	float spin;
	float squash;
	vec2 ring_axis;
	int ns;
	int total;
	bool pistil;
};

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec4 h42(vec2 p) {
	vec4 q = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	q += dot(q, q.wzxy + 33.33);
	return fract((q.xxyz + q.yzzw) * q.zywx);
}

float seg_t(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float l2 = dot(ab, ab);
	return l2 > 0.0001 ? clamp(dot(p - a, ab) / l2, 0.0, 1.0) : 0.0;
}

float drag_s(float t, float k) {
	return (1.0 - exp(-k * t)) / k;
}

float fw_rate() {
	return clamp(rate, 0.05, 3.0);
}

int fw_count() {
	return int(min(ceil(7.0 * fw_rate()) + 1.0, 30.0));
}

Burst make_burst(float slot, vec2 sz, float ps, float t, float sd) {
	Burst b;
	float r8 = fw_rate();
	b.slot = slot;
	b.hb = h42(vec2(slot * 1.37 + 11.0, sd * 0.731 + 5.0));
	b.hc = h42(vec2(slot * 2.11 + 3.0, sd * 1.173 + 17.0));
	b.hd = h42(vec2(slot * 0.71 + 29.0, sd * 0.379 + 41.0));
	b.launch = (slot + 0.1 + 0.8 * b.hb.x) / r8;
	b.rise_t = 1.15 + 0.45 * b.hb.y;
	b.kd = kind;
	if (b.kd == 0) {
		b.kd = b.hc.x < 0.38 ? 1 : (b.hc.x < 0.6 ? 4 : (b.hc.x < 0.8 ? 2 : 3));
	}
	b.lpos = vec2((launch_x + (b.hb.z - 0.5) * launch_area) * sz.x, sz.y + 12.0 * ps);
	b.bpos = vec2(b.lpos.x + (b.hb.w - 0.5) * 0.08 * sz.x, clamp(height + (b.hc.y - 0.5) * 0.18, 0.02, 0.98) * sz.y);
	b.scale = mix(0.78, 1.15, b.hc.z);
	b.a = t - (b.launch + b.rise_t);
	b.k = 1.5;
	b.life = 1.9;
	b.tt = trail;
	if (b.kd == 2) { b.k = 2.3; b.life = 3.6; b.tt = trail * 2.6 + 0.35; }
	if (b.kd == 3) { b.life = 1.7; }
	if (b.kd == 4) { b.k = 1.6; b.life = 1.35; }
	b.life *= mix(0.9, 1.12, b.hd.w);
	b.pop_end = b.kd == 4 ? 0.55 : 0.0;
	b.v0 = size * ps * b.scale * b.k;
	b.gk = gravity * ps / b.k;
	b.spin = b.hb.x * 6.2831853;
	b.squash = mix(0.15, 0.95, b.hd.y);
	float tilt = b.hd.x * 6.2831853;
	b.ring_axis = vec2(cos(tilt), sin(tilt));
	b.ns = clamp(stars, 16, 200);
	if (b.kd == 3) {
		b.ns = max(b.ns / 2, 16);
	}
	b.pistil = palette != 1 && b.hd.z < 0.45 && (b.kd == 1 || b.kd == 4);
	b.total = b.pistil ? b.ns + b.ns / 3 : b.ns;
	return b;
}

bool burst_live(Burst b) {
	return b.a >= 0.0 && b.a <= b.life + b.pop_end + b.tt + 0.2;
}

float burst_reach(Burst b, float core, float ps) {
	return b.v0 * drag_s(b.a, b.k) + b.gk * b.a * 0.6 + core * 14.0 + 30.0 * ps;
}

vec2 burst_centre(Burst b) {
	return b.bpos + vec2(0.0, b.gk * (b.a - drag_s(b.a, b.k)));
}

int star_sector(Burst b, int j) {
	float ang;
	if (b.kd == 3 && j < b.ns) {
		ang = 6.2831853 * float(j) / float(b.ns);
	} else {
		float jj = j >= b.ns ? float(j - b.ns) : float(j);
		ang = jj * 2.3999632 + b.spin;
	}
	return int(fract(ang / 6.2831853) * 8.0);
}

vec2 star_dir(Burst b, int j, vec4 hj) {
	float fj = float(j);
	bool inner = j >= b.ns;
	if (b.kd == 3 && !inner) {
		float ang = 6.2831853 * (fj + 0.15 * hj.x) / float(b.ns);
		vec2 cs = vec2(cos(ang), sin(ang) * b.squash);
		return b.ring_axis * cs.x + vec2(-b.ring_axis.y, b.ring_axis.x) * cs.y;
	}
	float nn = inner ? float(b.ns / 3) : float(b.ns);
	float jj = inner ? fj - float(b.ns) : fj;
	float z = 1.0 - (2.0 * jj + 1.0) / nn;
	float rr = sqrt(max(1.0 - z * z, 0.0));
	float ang = jj * 2.3999632 + b.spin + (hj.x - 0.5) * 0.5;
	return vec2(cos(ang), sin(ang)) * rr;
}

vec4 star_hash(Burst b, int j, float sd) {
	return h42(vec2(float(j) * 1.618 + b.slot * 3.7, sd + 91.0 + b.slot));
}

float star_speed(Burst b, int j, vec4 hj) {
	return b.v0 * (j >= b.ns ? 0.42 : mix(0.88, 1.0, hj.y));
}

float star_pad(Burst b, float core, float ps) {
	return core * 8.0 + b.gk * b.tt * 0.06 + (b.kd == 4 ? 26.0 * ps * b.scale : 0.0);
}

int burst_bits(Burst b) {
	return int(mod(b.slot, 4.0)) * 8;
}

uniform vec2 tex_size = vec2(1.0, 1.0);

vec3 chem(float pick) {
	float k = floor(pick * 9.0);
	if (k < 1.0) { return vec3(1.0, 0.1, 0.07); }
	if (k < 2.0) { return vec3(0.2, 1.0, 0.22); }
	if (k < 3.0) { return vec3(0.22, 0.38, 1.0); }
	if (k < 4.0) { return vec3(0.72, 0.22, 1.0); }
	if (k < 5.0) { return vec3(1.0, 0.62, 0.16); }
	if (k < 6.0) { return vec3(0.82, 0.88, 1.0); }
	if (k < 7.0) { return vec3(1.0, 0.4, 0.05); }
	if (k < 8.0) { return vec3(0.15, 0.95, 0.85); }
	return vec3(1.0, 0.28, 0.62);
}

vec3 gold_heat(float u) {
	vec3 a = vec3(1.0, 0.93, 0.78);
	vec3 b = vec3(1.0, 0.66, 0.26);
	vec3 c = vec3(0.95, 0.36, 0.07);
	vec3 d = vec3(0.55, 0.1, 0.02);
	if (u < 0.3) { return mix(a, b, u / 0.3); }
	if (u < 0.7) { return mix(b, c, (u - 0.3) / 0.4); }
	return mix(c, d, clamp((u - 0.7) / 0.3, 0.0, 1.0));
}

vec3 star_colour(vec3 base, bool gold, float u) {
	if (gold) {
		return gold_heat(u);
	}
	vec3 hot = vec3(1.0, 0.94, 0.82);
	vec3 ember = vec3(1.0, 0.32, 0.06);
	if (u < 0.14) { return mix(hot, base, smoothstep(0.0, 0.14, u)); }
	if (u < 0.68) { return base; }
	return mix(base, ember, smoothstep(0.68, 1.0, u));
}

float star_env(float u) {
	if (u < 0.0 || u > 1.0) { return 0.0; }
	float rise = mix(1.7, 1.0, smoothstep(0.0, 0.12, u));
	return rise * (1.0 - smoothstep(0.62, 1.0, u)) * mix(1.0, 0.75, u);
}

void fragment() {
	vec2 cells = max(tex_size, vec2(1.0));
	vec2 sz = max(1.0 / max(abs(vec2(dFdx(UV.x), dFdy(UV.y))), vec2(0.000001)), vec2(1.0));
	float ps = max(px_scale * sz.x / cells.x, 0.0001);
	vec4 mc = texelFetch(TEXTURE, ivec2(clamp(floor(UV * cells), vec2(0.0), cells - 1.0)), 0);
	uvec4 mb = uvec4(round(mc * 255.0));
	uint mask = mb.r | (mb.g << 8u) | (mb.b << 16u) | (mb.a << 24u);
	vec2 p = UV * sz;
	float t = clip_time;
	float sd = mod(float(seed), 9973.0);
	float g = gravity * ps;
	float sz_px = size * ps;
	float core = max(1.15 * ps, sz_px * 0.0055);
	vec3 acc = vec3(0.0);
	float last = floor(t * fw_rate());
	int count = fw_count();
	for (int n = 0; n < count; n++) {
		Burst b = make_burst(last - float(n), sz, ps, t, sd);
		float slot = b.slot;
		vec4 hb = b.hb;
		vec4 hc = b.hc;
		vec4 hd = b.hd;
		float launch = b.launch;
		float rise_t = b.rise_t;
		int kd = b.kd;
		vec2 lpos = b.lpos;
		vec2 bpos = b.bpos;
		float scale = b.scale;
		bool gold = palette == 1 || kd == 2;
		vec3 base = palette == 2 ? colour.rgb : chem(hc.w);
		vec3 base2 = chem(fract(hc.w + 0.37 + 0.4 * hd.x));
		bool two = palette == 0 && hd.y < 0.4 && kd != 2;
		float tr = t - launch;
		if (rockets && tr >= 0.0 && tr < rise_t + 0.25) {
			float te = min(tr, rise_t);
			vec2 lead = mix(lpos, bpos, 1.0 - pow(1.0 - te / rise_t, 2.0));
			float rbox = abs(p.x - lead.x);
			if (rbox < 60.0 * ps && p.y > lead.y - 40.0 * ps && p.y < lead.y + 0.42 * sz.y + 140.0 * ps) {
				float fade = tr > rise_t ? exp(-(tr - rise_t) / 0.06) : 1.0;
				float lit = tr > rise_t ? 0.0 : 1.0;
				vec2 prev = lead;
				for (int m = 1; m <= 4; m++) {
					float tb = max(te - float(m) * 0.07, 0.0);
					vec2 q = mix(lpos, bpos, 1.0 - pow(1.0 - tb / rise_t, 2.0));
					q.x += sin(tb * 13.0 + hb.x * 30.0) * 2.5 * ps;
					float w = seg_t(p, prev, q);
					vec2 c = mix(prev, q, w);
					float age = (float(m) - 1.0 + w) * 0.07;
					float glitter = 0.55 + 0.45 * h12(vec2(floor((te - age) * 60.0), slot + 7.0));
					float d = length(p - c);
					acc += vec3(1.0, 0.62, 0.22) * fade * exp(-age * 9.0) * glitter * (exp(-d * d / (0.5 * core * core)) * 1.4 + exp(-d / (core * 2.5)) * 0.12);
					prev = q;
				}
				float dh = length(p - lead);
				acc += vec3(1.0, 0.85, 0.6) * lit * (exp(-dh * dh / (0.7 * core * core)) * 2.4 + exp(-dh / (core * 3.0)) * 0.25);
				for (int m = 0; m < 9; m++) {
					vec4 hs = h42(vec2(float(m) * 3.3 + slot * 7.1, floor(tr * 14.0 - float(m)) + sd));
					float born = (floor(tr * 14.0 - float(m)) + hs.x) / 14.0;
					float age = tr - born;
					if (born < 0.0 || born > rise_t || age < 0.0 || age > 0.5) {
						continue;
					}
					vec2 o = mix(lpos, bpos, 1.0 - pow(1.0 - born / rise_t, 2.0));
					vec2 v = vec2((hs.y - 0.5) * 90.0, 10.0 + 50.0 * hs.z) * ps;
					vec2 sp = o + v * age + vec2(0.0, 0.5 * g * 1.6 * age * age);
					float d = length(p - sp);
					float life = 1.0 - age / 0.5;
					acc += gold_heat(1.0 - life) * life * exp(-d * d / (0.35 * core * core)) * 1.2;
				}
			}
		}
		if (!burst_live(b)) {
			continue;
		}
		float a = b.a;
		float k = b.k;
		float life = b.life;
		float tt = b.tt;
		float pop_end = b.pop_end;
		float fade_t = max(tt, 0.05) * 0.45;
		float v0 = b.v0;
		float gk = b.gk;
		vec2 centre = burst_centre(b);
		float reach = burst_reach(b, core, ps);
		float brk = exp(-a / 0.035);
		float db = length(p - bpos);
		acc += vec3(1.0, 0.9, 0.75) * brk * (exp(-db * db / (2.0 * pow(sz_px * scale * 0.025, 2.0))) * 3.0 + exp(-db / (sz_px * scale * 0.12)) * 0.4);
		vec2 dc = p - centre;
		if (dot(dc, dc) > reach * reach) {
			continue;
		}
		float tm[5];
		float sm[5];
		float gm[5];
		for (int m = 0; m < 5; m++) {
			float tk = max(a - tt * float(m) * 0.25, 0.0);
			tm[m] = tk;
			sm[m] = drag_s(tk, k);
			gm[m] = gk * (tk - sm[m]);
		}
		int bbase = burst_bits(b);
		uint bm = (mask >> uint(bbase)) & 255u;
		if (bm == 0u) {
			continue;
		}
		vec2 ring_axis = b.ring_axis;
		for (int j = 0; j < b.total; j++) {
			if ((bm & (1u << uint(star_sector(b, j)))) == 0u) {
				continue;
			}
			float fj = float(j);
			vec4 hj = star_hash(b, j, sd);
			bool inner = j >= b.ns;
			vec2 dir = star_dir(b, j, hj);
			float spd = star_speed(b, j, hj);
			float lj = life * mix(0.72, 1.0, hj.z) * (inner ? 0.8 : 1.0);
			vec2 head = bpos + dir * spd * sm[0] + vec2(0.0, gm[0]);
			vec2 tail = bpos + dir * spd * sm[4] + vec2(0.0, gm[4]);
			vec2 midp = bpos + dir * spd * sm[2] + vec2(0.0, gm[2]);
			float rad = star_pad(b, core, ps);
			vec2 d1 = p - mix(head, midp, seg_t(p, head, midp));
			vec2 d2 = p - mix(midp, tail, seg_t(p, midp, tail));
			if (min(dot(d1, d1), dot(d2, d2)) > rad * rad) {
				continue;
			}
			vec3 sc = inner ? base2 : ((two && dir.x * ring_axis.x + dir.y * ring_axis.y > 0.0) ? base2 : base);
			float twk = kd == 2 ? 0.75 : 0.45;
			float tb = kd == 2 ? 1.0 : (kd == 3 ? 0.35 : 0.6);
			vec2 prev = head;
			for (int m = 1; m < 5; m++) {
				vec2 q = bpos + dir * spd * sm[m] + vec2(0.0, gm[m]);
				float w = seg_t(p, prev, q);
				vec2 c = mix(prev, q, w);
				float tau = mix(tm[m - 1], tm[m], w);
				float age = a - tau;
				float u = tau / lj;
				float e = star_env(u);
				if (e > 0.0 && age > 0.0) {
					float d = length(p - c);
					float glit = 1.0 - twk * step(0.5, h12(vec2(floor(tau * 40.0 + hj.w * 9.0), fj + slot * 13.0)));
					vec3 tc = mix(star_colour(sc, gold, u), gold_heat(clamp(age / max(tt, 0.05), 0.0, 1.0) * 0.6 + 0.3), kd == 2 ? 1.0 : 0.55);
					float wd = core * mix(0.65, 0.4, clamp(age / max(tt, 0.05), 0.0, 1.0));
					acc += tc * e * glit * tb * exp(-age / fade_t) * (exp(-d * d / (2.0 * wd * wd)) * 0.75 + exp(-d / (wd * 4.0)) * 0.05);
				}
				prev = q;
			}
			float uh = a / lj;
			float eh = star_env(uh);
			if (eh > 0.0) {
				float d = length(p - head);
				float tw = 1.0;
				if (uh > 0.5) {
					tw = 1.0 - (kd == 2 ? 0.3 : 0.6) * step(0.55, h12(vec2(floor(a * 22.0 + hj.w * 5.0), fj * 1.3 + slot)));
				}
				vec3 hc3 = star_colour(sc, gold, uh);
				acc += hc3 * eh * tw * (exp(-d * d / (2.0 * core * core)) * 2.2 + exp(-d / (core * 2.2)) * 0.22 * smoothstep(0.0, 0.2, a));
			}
			if (kd == 4 && a > lj * 0.9 && a < lj + pop_end) {
				for (int c2 = 0; c2 < 4; c2++) {
					vec4 hp = h42(vec2(fj * 5.1 + float(c2) * 1.7, slot * 2.9 + sd));
					float pt = lj * 0.9 + hp.x * (pop_end + lj * 0.1);
					float pa = a - pt;
					if (pa < 0.0 || pa > 0.07) {
						continue;
					}
					float sp = drag_s(pt, k);
					vec2 pp = bpos + dir * spd * sp + vec2(0.0, gk * (pt - sp)) + (hp.yz - 0.5) * 34.0 * ps * scale;
					float d = length(p - pp);
					float fl = 1.0 - pa / 0.07;
					acc += vec3(1.0, 0.95, 0.8) * fl * (exp(-d * d / (1.4 * core * core)) * 3.0 + exp(-d / (core * 3.5)) * 0.4);
				}
			}
		}
	}
	vec3 col = vec3(1.0) - exp(-acc * 1.15);
	COLOR = vec4(col, 1.0);
}
