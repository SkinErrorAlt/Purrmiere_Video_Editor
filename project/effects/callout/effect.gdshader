shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform int shape : hint_range(0, 4) = 1;
uniform vec2 target = vec2(0.62, 0.42);
uniform vec2 arrow_from = vec2(0.3, 0.8);
uniform float size : hint_range(0.02, 0.8) = 0.13;
uniform float stretch : hint_range(0.3, 3.0) = 1.35;
uniform vec4 colour : source_color = vec4(0.95, 0.1, 0.1, 1.0);
uniform float thickness : hint_range(1.0, 40.0) = 7.0;
uniform float wobble : hint_range(0.0, 1.0) = 0.5;
uniform float outline : hint_range(0.0, 1.0) = 0.4;
uniform float starts_at : hint_range(0.0, 600.0) = 0.0;
uniform float draw_time : hint_range(0.0, 3.0) = 0.45;
uniform int seed : hint_range(0, 9999) = 0;

const int SEGS = 20;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.000001), 0.0, 1.0);
	return length(pa - ba * h);
}

float box_sd(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - (b - vec2(r));
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

vec2 bez(vec2 a, vec2 c, vec2 b, float t) {
	float u = 1.0 - t;
	return u * u * a + 2.0 * u * t * c + t * t * b;
}

vec4 over(vec4 top, vec4 under) {
	return top + under * (1.0 - top.a);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float t = clip_time - starts_at;
	if (t < 0.0) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float ps = max(px_scale, 0.0001);
		float dp = draw_time <= 0.001 ? 1.0 : clamp(t / draw_time, 0.0, 1.0);
		bool has_ring = shape != 4;
		bool has_arrow = shape == 1 || shape == 3 || shape == 4;
		bool is_box = shape == 2 || shape == 3;
		float ring_p = dp;
		float arrow_p = dp;
		if (has_ring && has_arrow) {
			ring_p = clamp(dp / 0.6, 0.0, 1.0);
			arrow_p = clamp((dp - 0.6) / 0.4, 0.0, 1.0);
		}
		float sd = float(seed) * 1.37;
		float wob = clamp(wobble, 0.0, 1.0);
		float rr0 = max(size, 0.001) * sz.y;
		vec2 ab = vec2(rr0 * max(stretch, 0.05), rr0);
		vec2 tp = target * sz;
		vec2 pix = UV * sz;
		vec2 d = pix - tp;
		vec2 v = d / ab;
		float rho = length(v);
		float phi = atan(v.y, v.x);
		float th0 = -2.3 + (hash11(sd + 1.0) - 0.5) * 1.2;
		float dmin = 1000000.0;
		if (has_ring && ring_p > 0.0) {
			float local_r = length(vec2(ab.x * cos(phi), ab.y * sin(phi)));
			if (is_box) {
				float frac = mod(phi - th0, TAU) / TAU;
				if (frac <= ring_p) {
					float jit = wob * (0.03 * sin(phi * 3.0 + sd) + 0.02 * sin(phi * 7.0 + sd * 2.0)) * rr0;
					dmin = min(dmin, abs(box_sd(d, ab, rr0 * 0.12) + jit));
				}
			} else {
				float s1 = hash11(sd + 3.0) * TAU;
				float s2 = hash11(sd + 5.0) * TAU;
				for (int k = 0; k < 2; k++) {
					float rel = mod(phi - th0, TAU) + TAU * float(k);
					if (rel <= TAU * 1.12 * ring_p) {
						float rr = 1.0 + 0.07 * (rel / TAU) - 0.035 + wob * (0.05 * sin(3.0 * rel + s1) + 0.035 * sin(5.0 * rel + s2));
						dmin = min(dmin, abs(rho - rr) * local_r);
					}
				}
			}
		}
		if (has_arrow && arrow_p > 0.0) {
			vec2 a = arrow_from * sz;
			vec2 to_a = a - tp;
			float la = length(to_a);
			if (la > 1.0) {
				vec2 dirn = to_a / la;
				vec2 b = tp;
				if (has_ring) {
					float ca = dirn.x;
					float sa = dirn.y;
					float re = ab.x * ab.y / max(sqrt(ab.y * ab.y * ca * ca + ab.x * ab.x * sa * sa), 0.0001);
					b = tp + dirn * (re * 1.12 + thickness * ps * 1.5);
				}
				vec2 ba = a - b;
				float lab = length(ba);
				if (lab > 2.0 && dot(ba, dirn) > 0.0) {
					vec2 perp = vec2(-ba.y, ba.x) / lab;
					float bend = (hash11(sd + 7.0) < 0.5 ? 1.0 : -1.0) * (0.06 + 0.1 * wob);
					vec2 ctrl = (a + b) * 0.5 + perp * bend * lab;
					for (int j = 0; j < SEGS; j++) {
						float t0 = float(j) / float(SEGS);
						if (t0 >= arrow_p) {
							break;
						}
						float t1 = min(float(j + 1) / float(SEGS), arrow_p);
						dmin = min(dmin, seg_dist(pix, bez(a, ctrl, b, t0), bez(a, ctrl, b, t1)));
					}
					float head_p = smoothstep(0.8, 1.0, arrow_p);
					if (head_p > 0.0) {
						vec2 tip = bez(a, ctrl, b, arrow_p);
						vec2 tg = normalize(tip - bez(a, ctrl, b, max(arrow_p - 0.05, 0.0)) + vec2(0.000001));
						float hl = max(14.0 * ps, 3.2 * thickness * ps) * head_p;
						float cs = cos(0.5);
						float sn = sin(0.5);
						vec2 h1 = vec2(cs * tg.x - sn * tg.y, sn * tg.x + cs * tg.y);
						vec2 h2 = vec2(cs * tg.x + sn * tg.y, -sn * tg.x + cs * tg.y);
						dmin = min(dmin, seg_dist(pix, tip, tip - h1 * hl));
						dmin = min(dmin, seg_dist(pix, tip, tip - h2 * hl));
					}
				}
			}
		}
		float hw = max(thickness, 0.5) * ps * 0.5;
		float aa = max(ps, 0.5) * 0.75;
		float cov = clamp(0.5 - (dmin - hw) / aa, 0.0, 1.0);
		float ow = max(1.5 * ps, 0.35 * hw);
		float cov_o = clamp(0.5 - (dmin - hw - ow) / aa, 0.0, 1.0) * clamp(outline, 0.0, 1.0);
		vec4 layer = vec4(colour.rgb, 1.0) * colour.a * cov;
		layer = over(layer, vec4(colour.rgb * 0.2, 1.0) * colour.a * cov_o);
		COLOR = over(layer, c);
	}
}
