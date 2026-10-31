shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 source = vec2(0.32, 0.55);
uniform float angle : hint_range(-180.0, 180.0) = -35.0;
uniform float spread : hint_range(0.0, 180.0) = 40.0;
uniform float rate : hint_range(0.1, 600.0) = 320.0;
uniform float speed : hint_range(20.0, 4000.0) = 1100.0;
uniform float gravity : hint_range(0.0, 5000.0) = 1700.0;
uniform float drag : hint_range(0.0, 8.0) = 1.8;
uniform float life : hint_range(0.1, 4.0) = 1.1;
uniform float floor_y : hint_range(0.0, 1.5) = 0.88;
uniform float bounce : hint_range(0.0, 1.0) = 0.35;
uniform float streak : hint_range(0.0, 1.0) = 0.6;
uniform vec4 colour : source_color = vec4(1.0, 0.45, 0.08, 1.0);
uniform float glow : hint_range(0.0, 3.0) = 1.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform float px_scale = 1.0;
uniform float clip_time;

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

vec2 fly(vec2 p, vec2 v, float k, float g, float x) {
	float s = (1.0 - exp(-k * x)) / k;
	float vt = g / k;
	return p + vec2(v.x * s, (v.y - vt) * s + vt * x);
}

vec2 speed_at(vec2 v, float k, float g, float x) {
	float e = exp(-k * x);
	float vt = g / k;
	return vec2(v.x * e, (v.y - vt) * e + vt);
}

float hit_time(vec2 p, vec2 v, float k, float g, float fy) {
	float dy = max(fy - p.y, 0.0);
	float x = (-v.y + sqrt(max(v.y * v.y + 2.0 * g * dy, 0.0))) / max(g, 0.001);
	x = max(x, 0.0005);
	float vt = g / k;
	for (int i = 0; i < 4; i++) {
		float e = exp(-k * x);
		float s = (1.0 - e) / k;
		float f = p.y + (v.y - vt) * s + vt * x - fy;
		float d = (v.y - vt) * e + vt;
		x = x - f / max(d, 1.0);
	}
	return max(x, 0.0);
}

float seg_t(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float l2 = dot(ab, ab);
	return l2 > 0.0001 ? clamp(dot(p - a, ab) / l2, 0.0, 1.0) : 0.0;
}

bool spark_path(float idx, float grp, vec2 p, vec2 sz, float ps, float pad, out vec2 q0, out vec2 q1, out vec2 q2, out vec2 q3, out vec4 heat, out float spark_w) {
	q0 = vec2(0.0);
	q1 = vec2(0.0);
	q2 = vec2(0.0);
	q3 = vec2(0.0);
	heat = vec4(0.0);
	spark_w = 0.0;
	float t = clip_time;
	float sd = mod(float(seed), 9973.0);
	float r8 = clamp(rate, 0.1, 600.0);
	vec4 ha = h42(vec2(idx * 0.917 + 3.0, sd * 1.31 + 7.0));
	float tau = t - (idx + ha.x) / r8;
	float lf = life * mix(0.45, 1.2, ha.y);
	if (tau < 0.0 || tau > lf) {
		return false;
	}
	vec4 hb = h42(vec2(idx * 1.733 + 19.0, sd * 0.77 + 2.0));
	float ab = mod(grp, 8.0);
	float sb = floor(grp / 8.0);
	float u = ((ab + ha.z) / 8.0) * 2.0 - 1.0;
	float dev = 0.55 * u + 0.45 * u * u * u;
	float an = radians(angle + spread * dev);
	float sp = speed * ps * mix(0.3, 1.0, (sb + ha.w) / 4.0);
	vec2 v0 = vec2(cos(an), sin(an)) * sp;
	float k = max(drag * mix(0.6, 1.5, hb.y), 0.05);
	vec2 src = source * sz;
	float g = max(gravity * ps, 0.5);
	float fy = floor_y * sz.y;
	bool has_floor = fy > src.y + 1.0;
	float sx = (1.0 - exp(-k * tau)) / k;
	float xr = src.x + v0.x * sx;
	if (p.x < min(src.x, xr) - pad || p.x > max(src.x, xr) + pad) {
		return false;
	}
	float ytop = v0.y < 0.0 ? src.y - v0.y * v0.y / (2.0 * g) : src.y;
	if (p.y < ytop - pad || (has_floor && p.y > fy + pad)) {
		return false;
	}
	vec2 pb = src;
	vec2 vb = v0;
	vec2 pc = src;
	vec2 vc = v0;
	float t1 = 1e6;
	float t2 = 1e6;
	if (has_floor) {
		t1 = hit_time(src, v0, k, g, fy);
		if (t1 < tau) {
			pb = vec2(fly(src, v0, k, g, t1).x, fy);
			vec2 vh = speed_at(v0, k, g, t1);
			vb = vec2(vh.x * mix(0.55, 0.92, hb.z), -abs(vh.y) * bounce * mix(0.7, 1.0, hb.x));
			if (abs(vb.y) > 25.0 * ps) {
				t2 = t1 + hit_time(pb, vb, k, g, fy);
				if (t2 < tau) {
					pc = vec2(fly(pb, vb, k, g, t2 - t1).x, fy);
					vec2 vh2 = speed_at(vb, k, g, t2 - t1);
					vc = vec2(vh2.x * mix(0.55, 0.92, hb.w), -abs(vh2.y) * bounce * mix(0.7, 1.0, ha.z));
				}
			}
		}
	}
	float shutter = streak * 0.07 + 0.003;
	vec2 qs[4];
	for (int m = 0; m < 4; m++) {
		float x = max(tau - shutter * float(m) / 3.0, 0.0);
		vec2 q;
		vec2 vq;
		float bn = 0.0;
		if (x < t1) {
			q = fly(src, v0, k, g, x);
			vq = speed_at(v0, k, g, x);
		} else if (x < t2) {
			q = fly(pb, vb, k, g, x - t1);
			vq = speed_at(vb, k, g, x - t1);
			bn = 1.0;
		} else {
			q = fly(pc, vc, k, g, x - t2);
			vq = speed_at(vc, k, g, x - t2);
			bn = 2.0;
		}
		if (has_floor) {
			q.y = min(q.y, fy);
		}
		qs[m] = q;
		float age = x / lf;
		float sf = clamp(length(vq) / max(sp, 1.0), 0.0, 1.0);
		heat[m] = clamp((1.0 - pow(age, 1.4)) * (0.5 + 0.5 * sf) * (1.0 - 0.12 * bn) * mix(0.82, 1.0, hb.w), 0.0, 1.0) * smoothstep(0.0, 0.08, 1.0 - age);
	}
	q0 = qs[0];
	q1 = qs[1];
	q2 = qs[2];
	q3 = qs[3];
	spark_w = mix(0.8, 1.25, hb.z);
	return true;
}

uniform vec2 tex_size = vec2(1.0, 1.0);

void fragment() {
	vec2 full = max(tex_size, vec2(1.0));
	vec2 cells = max(1.0 / max(abs(vec2(dFdx(UV.x), dFdy(UV.y))), vec2(0.000001)), vec2(1.0));
	vec2 tile = full / cells;
	vec2 cell = floor(UV * cells);
	vec2 p = (cell + 0.5) * tile;
	float ps = max(px_scale, 0.0001);
	float core = max(0.85 * ps, 0.7);
	float pad = length(tile) * 0.5 + core * 9.0 + 1.0;
	float r8 = clamp(rate, 0.1, 600.0);
	float last = floor(clip_time * r8);
	int count = int(min(ceil(life * 1.2 * r8) + 1.0, 1400.0));
	uint m = 0u;
	for (int n = 0; n < count; n++) {
		float idx = last - float(n);
		float grp = mod(idx, 32.0);
		uint bit = 1u << uint(grp);
		if ((m & bit) != 0u) {
			continue;
		}
		vec2 q0;
		vec2 q1;
		vec2 q2;
		vec2 q3;
		vec4 heat;
		float w;
		if (!spark_path(idx, grp, p, full, ps, pad, q0, q1, q2, q3, heat, w)) {
			continue;
		}
		if (max(max(heat.x, heat.y), max(heat.z, heat.w)) < 0.01) {
			continue;
		}
		float d = length(p - mix(q0, q1, seg_t(p, q0, q1)));
		d = min(d, length(p - mix(q1, q2, seg_t(p, q1, q2))));
		d = min(d, length(p - mix(q2, q3, seg_t(p, q2, q3))));
		if (d < pad) {
			m |= bit;
		}
	}
	COLOR = vec4(float(m & 255u), float((m >> 8u) & 255u), float((m >> 16u) & 255u), float((m >> 24u) & 255u)) / 255.0;
}
