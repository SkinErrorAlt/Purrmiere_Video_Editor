shader_type canvas_item;
render_mode blend_disabled;

uniform float pitch : hint_range(6.0, 80.0) = 22.0;
uniform int bead_colours = 0;
uniform float ironed : hint_range(0.0, 1.0) = 0.35;
uniform float gloss : hint_range(0.0, 1.0) = 0.6;
uniform float light_angle : hint_range(-180.0, 180.0) = -135.0;
uniform vec4 board : source_color = vec4(0.16, 0.16, 0.17, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

const vec3 PAL[30] = vec3[](
	vec3(0.95, 0.95, 0.93), vec3(0.93, 0.89, 0.76), vec3(0.98, 0.86, 0.2), vec3(0.97, 0.62, 0.12),
	vec3(0.86, 0.15, 0.16), vec3(0.58, 0.1, 0.14), vec3(0.98, 0.68, 0.74), vec3(0.89, 0.33, 0.58),
	vec3(0.52, 0.27, 0.62), vec3(0.73, 0.65, 0.86), vec3(0.15, 0.22, 0.55), vec3(0.24, 0.47, 0.8),
	vec3(0.55, 0.78, 0.93), vec3(0.18, 0.66, 0.68), vec3(0.15, 0.55, 0.27), vec3(0.08, 0.32, 0.18),
	vec3(0.6, 0.82, 0.35), vec3(0.47, 0.29, 0.17), vec3(0.32, 0.2, 0.13), vec3(0.78, 0.6, 0.42),
	vec3(0.96, 0.78, 0.62), vec3(0.72, 0.38, 0.22), vec3(0.55, 0.55, 0.56), vec3(0.78, 0.78, 0.78),
	vec3(0.33, 0.33, 0.35), vec3(0.08, 0.08, 0.09), vec3(0.45, 0.4, 0.36), vec3(0.85, 0.75, 0.55),
	vec3(0.98, 0.94, 0.55), vec3(0.62, 0.15, 0.32)
);

float h12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 h22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 snap_bead(vec3 c) {
	vec3 best = PAL[0];
	float bd = 1e9;
	for (int i = 0; i < 30; i++) {
		vec3 d = c - PAL[i];
		float rm = 0.5 * (c.r + PAL[i].r);
		float e = (2.0 + rm) * d.r * d.r + 4.0 * d.g * d.g + (3.0 - rm) * d.b * d.b;
		if (e < bd) {
			bd = e;
			best = PAL[i];
		}
	}
	return best;
}

float shape(vec2 q, float n) {
	vec2 a = abs(q);
	return pow(pow(a.x, n) + pow(a.y, n), 1.0 / n);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float ps = max(px_scale, 0.0001);
	vec2 p = UV * tex_size / ps;
	float P = max(pitch, 3.0);
	vec2 so = vec2(float(seed) * 1.37, float(seed) * 2.91);
	float iron = clamp(ironed, 0.0, 1.0);
	float n = mix(2.0, 4.2, iron);
	float R = P * mix(0.47, 0.56, iron);
	float rh = mix(0.42, 0.22, iron);
	float la = radians(light_angle);
	vec3 L = normalize(vec3(cos(la), sin(la), 1.1));
	vec2 cell = floor(p / P);
	float best_h = -1.0;
	vec3 shade = board.rgb;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 id = cell + vec2(float(x), float(y));
			vec2 jit = (h22(id + so) - 0.5) * P * 0.05;
			vec2 ctr = (id + 0.5) * P + jit;
			vec2 q = (p - ctr) / R;
			float rr = shape(q, n);
			if (rr > 1.0) {
				continue;
			}
			float melt = clamp(iron + (h12(id + so * 3.0) - 0.5) * 0.25, 0.0, 1.0);
			float rhole = rh * mix(1.0, 0.8, h12(id + so + 5.0)) * (1.0 - 0.15 * melt);
			float rc = (1.0 + rhole) * 0.5;
			float hw = (1.0 - rhole) * 0.5;
			float t = (rr - rc) / hw;
			float hh;
			float dh;
			if (rr < rhole) {
				hh = -0.5;
				dh = 0.0;
			} else {
				float k = mix(1.0, 5.0, melt);
				float s = clamp(1.0 - abs(t), 0.0, 1.0);
				float flat_top = clamp(s * k, 0.0, 1.0);
				float round_top = sqrt(max(1.0 - t * t, 0.0));
				hh = mix(round_top, 1.0 - pow(1.0 - flat_top, 2.0), melt);
				float tc = clamp(t, -0.999, 0.999);
				float d_round = -tc / sqrt(max(1.0 - tc * tc, 0.002));
				float d_flat = (flat_top < 1.0 ? -sign(t) * 2.0 * (1.0 - flat_top) * k : 0.0);
				dh = mix(d_round, d_flat, melt) / hw;
			}
			float zorder = hh + h12(id + so + 9.0) * 0.05;
			if (zorder > best_h) {
				best_h = zorder;
				vec2 sp = clamp((ctr + vec2(-0.2, -0.2) * P) * ps / tex_size, vec2(0.0), vec2(1.0));
				vec2 sp2 = clamp((ctr + vec2(0.2, 0.2) * P) * ps / tex_size, vec2(0.0), vec2(1.0));
				vec2 sp3 = clamp((ctr + vec2(0.2, -0.2) * P) * ps / tex_size, vec2(0.0), vec2(1.0));
				vec2 sp4 = clamp((ctr + vec2(-0.2, 0.2) * P) * ps / tex_size, vec2(0.0), vec2(1.0));
				vec4 sc = (texture(TEXTURE, sp) + texture(TEXTURE, sp2) + texture(TEXTURE, sp3) + texture(TEXTURE, sp4)) * 0.25;
				vec3 c = sc.rgb / max(sc.a, 0.0001);
				vec3 bc = bead_colours == 0 ? snap_bead(c) : c;
				bc *= 0.96 + 0.08 * h12(id + so + 2.0);
				vec2 radial = length(q) > 0.0001 ? normalize(q) : vec2(0.0);
				vec3 N = normalize(vec3(-radial * dh * 0.55, 1.0));
				if (rr < rhole) {
					float inner = rr / max(rhole, 0.001);
					vec3 holec = mix(board.rgb * 0.6, bc * 0.35, smoothstep(0.55, 1.0, inner));
					float lit = clamp(dot(normalize(q + 0.0001), -normalize(L.xy)), 0.0, 1.0);
					shade = holec + bc * 0.25 * lit * smoothstep(0.6, 1.0, inner);
				} else {
					float diff = clamp(dot(N, L), 0.0, 1.0);
					vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
					float spec = pow(clamp(dot(N, H), 0.0, 1.0), mix(18.0, 60.0, melt)) * gloss;
					float ao = mix(0.7, 1.0, clamp(hh, 0.0, 1.0));
					vec3 lit = bc * (0.35 + 0.75 * diff) * ao;
					lit += bc * 0.12 * (1.0 - diff);
					shade = lit + vec3(spec) * 0.8;
				}
			}
		}
	}
	if (best_h < -0.9) {
		vec2 g = fract(p / P) - 0.5;
		float peg = 1.0 - smoothstep(0.12, 0.17, length(g));
		shade = board.rgb * (0.85 + 0.15 * h12(floor(p * 0.5) + so)) + peg * 0.08;
	}
	COLOR = vec4(clamp(shade, 0.0, 1.0) * base.a, base.a);
}
