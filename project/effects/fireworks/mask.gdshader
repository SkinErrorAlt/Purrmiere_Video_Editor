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

void fragment() {
	vec2 full = max(tex_size, vec2(1.0));
	vec2 cells = max(1.0 / max(abs(vec2(dFdx(UV.x), dFdy(UV.y))), vec2(0.000001)), vec2(1.0));
	vec2 tile = full / cells;
	vec2 p = (floor(UV * cells) + 0.5) * tile;
	float ps = max(px_scale, 0.0001);
	float t = clip_time;
	float sd = mod(float(seed), 9973.0);
	float core = max(1.15 * ps, size * ps * 0.0055);
	float tpad = length(tile) * 0.5 + 1.0;
	float last = floor(t * fw_rate());
	int count = fw_count();
	uint m = 0u;
	for (int n = 0; n < count; n++) {
		Burst b = make_burst(last - float(n), full, ps, t, sd);
		if (!burst_live(b)) {
			continue;
		}
		float reach = burst_reach(b, core, ps) + tpad;
		vec2 dc = p - burst_centre(b);
		if (dot(dc, dc) > reach * reach) {
			continue;
		}
		int base = burst_bits(b);
		float s0 = drag_s(b.a, b.k);
		float t2 = max(b.a - b.tt * 0.5, 0.0);
		float t4 = max(b.a - b.tt, 0.0);
		float s2 = drag_s(t2, b.k);
		float s4 = drag_s(t4, b.k);
		vec2 g0 = vec2(0.0, b.gk * (b.a - s0));
		vec2 g2 = vec2(0.0, b.gk * (t2 - s2));
		vec2 g4 = vec2(0.0, b.gk * (t4 - s4));
		float rad = star_pad(b, core, ps) + tpad;
		for (int j = 0; j < b.total; j++) {
			uint bit = 1u << uint(base + star_sector(b, j));
			if ((m & bit) != 0u) {
				continue;
			}
			vec4 hj = star_hash(b, j, sd);
			vec2 dir = star_dir(b, j, hj);
			float spd = star_speed(b, j, hj);
			vec2 head = b.bpos + dir * spd * s0 + g0;
			vec2 midp = b.bpos + dir * spd * s2 + g2;
			vec2 tail = b.bpos + dir * spd * s4 + g4;
			vec2 d1 = p - mix(head, midp, seg_t(p, head, midp));
			vec2 d2 = p - mix(midp, tail, seg_t(p, midp, tail));
			if (min(dot(d1, d1), dot(d2, d2)) <= rad * rad) {
				m |= bit;
			}
		}
	}
	COLOR = vec4(float(m & 255u), float((m >> 8u) & 255u), float((m >> 16u) & 255u), float((m >> 24u) & 255u)) / 255.0;
}
