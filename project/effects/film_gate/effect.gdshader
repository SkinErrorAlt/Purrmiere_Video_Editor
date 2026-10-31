shader_type canvas_item;
render_mode blend_disabled;

uniform int format : hint_range(0, 2) = 0;
uniform float corner : hint_range(0.0, 1.0) = 0.5;
uniform float softness : hint_range(0.0, 60.0) = 8.0;
uniform float darkness : hint_range(0.0, 1.0) = 0.6;
uniform bool hair = true;
uniform int seed : hint_range(0, 9999) = 0;
uniform bool frame_line = true;
uniform float jitter : hint_range(0.0, 1.0) = 0.3;
uniform float overscan : hint_range(0.0, 1.0) = 0.3;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float time = 0.0;
uniform float seq_fps = 30.0;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float vn1(float x, float row) {
	return vn(vec2(x, row));
}

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0000001), 0.0, 1.0);
	return length(pa - ba * h);
}

vec2 hair_point(float s, vec2 root, vec2 dir, float len, vec4 shape, vec2 so) {
	vec2 perp = vec2(-dir.y, dir.x);
	float wob = 0.035 * s * sin(time * 1.7 + s * 4.0 + so.x) + 0.02 * s * s * sin(time * 2.9 + s * 7.0 + so.y);
	float bend = shape.x * sin(3.14159265 * shape.z * s) + shape.y * s * s + shape.w * sin(9.0 * s + so.x) * s * 0.15 + wob;
	return root + dir * s * len * (1.0 - 0.15 * s * s) + perp * len * bend;
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 S = dims / ps;
	float asp = S.x / S.y;
	float pxh = 1.0 / (S.y * ps);
	vec2 p = (UV - 0.5) * vec2(asp, 1.0);
	float fs = float(seed);
	vec2 so = vec2(mod(fs * 12.9898, 97.0), mod(fs * 78.233, 91.0));
	float r_fmt = 0.1;
	float n = 2.5;
	float soft_mul = 1.35;
	float irr = 0.004;
	float fl = 0.055;
	if (format == 1) {
		r_fmt = 0.055;
		n = 3.2;
		soft_mul = 1.0;
		irr = 0.0022;
		fl = 0.05;
	} else if (format == 2) {
		r_fmt = 0.025;
		n = 4.5;
		soft_mul = 0.75;
		irr = 0.0012;
		fl = 0.042;
	}
	float m = 0.012 + overscan * 0.09;
	float hx = asp * 0.5 - m;
	float hy = 0.5 - m;
	float r = min(r_fmt * (0.15 + 1.7 * corner), hy * 0.9);
	vec2 qd = vec2(p.x < 0.0 ? -1.0 : 1.0, p.y < 0.0 ? -1.0 : 1.0);
	float rq = r * (0.78 + 0.44 * h12(qd * 3.1 + so));
	float bowx = 0.004 * (1.0 - (p.y / hy) * (p.y / hy));
	float bowy = 0.003 * (1.0 - clamp((p.x / hx) * (p.x / hx), 0.0, 1.0));
	float irrx = (vn1(p.y * 9.0 + so.x + qd.x * 7.0, 1.0) - 0.5) * irr + (vn1(p.y * 140.0 + so.x + qd.x * 3.0, 2.0) - 0.5) * irr * 0.4;
	float irry = (vn1(p.x * 9.0 + so.y + qd.y * 7.0, 3.0) - 0.5) * irr + (vn1(p.x * 140.0 + so.y + qd.y * 3.0, 4.0) - 0.5) * irr * 0.4;
	vec2 half_size = vec2(hx + bowx + irrx, hy + bowy + irry);
	vec2 q = abs(p) - (half_size - rq);
	vec2 qo = max(q, vec2(0.0));
	float dc = qo.x + qo.y > 0.0 ? pow(pow(qo.x, n) + pow(qo.y, n), 1.0 / n) : 0.0;
	float d = dc + min(max(q.x, q.y), 0.0) - rq;
	float w = max(softness * soft_mul / S.y, pxh * 1.2);
	float open = 1.0 - smoothstep(-0.5 * w, 0.5 * w, d);
	float fr = floor(time * max(seq_fps, 1.0) + 0.001);
	float jt = clamp(jitter, 0.0, 1.0);
	float wy = (vn1(fr * 0.23 + so.x, 5.0) - 0.5) * 2.0 * 0.005 * jt + (h12(vec2(fr, 9.0) + so) - 0.5) * 0.003 * jt;
	float wx = (vn1(fr * 0.17 + so.y, 6.0) - 0.5) * 2.0 * 0.0025 * jt;
	if (h12(vec2(fr, 13.0) + so) < jt * (0.06 + 0.14 * jt)) {
		wy += (h12(vec2(fr, 17.0) + so) < 0.5 ? -1.0 : 1.0) * jt * (0.035 + 0.055 * h12(vec2(fr, 19.0) + so));
	}
	vec2 f = p - vec2(wx, wy);
	float FH = 0.5 - m + 0.012;
	float T = 2.0 * FH + fl;
	float yy = f.y + FH + fl * 0.5;
	float local = yy - floor(yy / T) * T;
	float pic_y = local - fl * 0.5 - FH;
	float line_mask = frame_line ? smoothstep(FH - pxh, FH + pxh, abs(pic_y)) : 0.0;
	vec2 suv = clamp(vec2(0.5 + f.x / asp, 0.5 + clamp(pic_y, -0.5, 0.5)), vec2(0.0), vec2(1.0));
	vec4 c0 = texture(TEXTURE, UV);
	float a = c0.a;
	vec4 cs = texture(TEXTURE, suv);
	vec3 pic = cs.a > 0.0001 ? clamp(cs.rgb / cs.a, 0.0, 1.0) : vec3(0.0);
	vec3 film = mix(pic, vec3(0.03, 0.024, 0.02), line_mask);
	float bw = (0.02 + 0.045 * darkness) * (0.7 + 0.6 * vn(p * 7.0 + so));
	float burn = clamp(darkness, 0.0, 1.0) * exp(-max(-d, 0.0) / bw);
	film *= mix(vec3(1.0), vec3(0.3, 0.15, 0.07), burn);
	vec3 outside = vec3(0.014, 0.011, 0.009);
	vec3 col = mix(outside, film, open);
	if (hair) {
		float side = floor(h12(so + 1.3) * 4.0);
		float along = mix(-0.6, 0.6, h12(so + 2.1));
		vec2 root;
		vec2 dir;
		if (side < 1.0) {
			root = vec2(along * hx, -hy - 0.03);
			dir = vec2(0.0, 1.0);
		} else if (side < 2.0) {
			root = vec2(along * hx, hy + 0.03);
			dir = vec2(0.0, -1.0);
		} else if (side < 3.0) {
			root = vec2(-hx - 0.03, along * hy);
			dir = vec2(1.0, 0.0);
		} else {
			root = vec2(hx + 0.03, along * hy);
			dir = vec2(-1.0, 0.0);
		}
		float tilt = (h12(so + 8.8) - 0.5) * 1.1;
		dir = normalize(dir + vec2(-dir.y, dir.x) * tilt);
		float len = mix(0.13, 0.3, h12(so + 3.7));
		vec4 shape = vec4((h12(so + 4.1) - 0.5) * 0.45, (h12(so + 5.3) - 0.5) * 0.7, mix(0.8, 2.4, h12(so + 6.2)), h12(so + 7.4) - 0.5);
		float dist = 1.0;
		vec2 prev = hair_point(0.0, root, dir, len, shape, so);
		for (int i = 1; i <= 16; i++) {
			float s = float(i) / 16.0;
			vec2 cur = hair_point(s, root, dir, len, shape, so);
			dist = min(dist, seg_dist(p, prev, cur));
			prev = cur;
		}
		float hw = max(0.0011, pxh * 0.5);
		float blur = 0.0009 + pxh * 0.5;
		float cov = (1.0 - smoothstep(hw - blur, hw + blur, dist)) * min(1.0, 0.0011 / (pxh * 0.5));
		col *= 1.0 - 0.9 * cov;
	}
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}
