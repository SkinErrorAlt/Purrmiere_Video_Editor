shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_motion_kit/kit.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(2.0);
uniform float px_scale = 1.0;
uniform float max_len = 120.0;
uniform float spacing = 6.0;
uniform float width = 8.0;
uniform float trail = 0.7;
uniform float bristles = 0.5;
uniform float relief = 0.5;
uniform float colour_jitter = 0.35;

vec4 field_at(sampler2D f, vec2 uv) {
	vec4 c = texture(f, uv);
	return vec4(normalize(c.rg * 2.0 - 1.0 + vec2(1e-5, 0.0)), c.b, c.a);
}

vec3 unpremul(vec4 c, vec3 fallback) {
	return c.a > 0.0001 ? c.rgb / c.a : fallback;
}

void fragment() {
	vec2 out_size = vec2(textureSize(effect_tex, 0));
	float ps = max(px_scale * out_size.x / max(tex_size.x, 1.0), 0.0001);
	vec4 src = texture(effect_tex, UV);
	float a = src.a;
	vec3 pic = unpremul(src, vec3(0.0));
	vec2 p = UV * out_size;
	vec4 f0 = field_at(TEXTURE, UV);
	float L = max(f0.a * max_len * ps, 3.0 * ps);
	float tr = trail * f0.b;
	float back = 0.5 + 0.5 * tr;
	float fwd = 1.0 - back;
	float S1 = max(spacing * ps, 1.5);
	float wbase = width * ps;
	float best_pri = -1.0;
	vec2 best_seed = p;
	float best_u = 0.0;
	float best_lat = 0.0;
	float best_w = 1.0;
	float best_h = 0.0;
	vec2 best_dir = f0.xy;
	const int STEPS = 13;
	for (int side = 0; side < 2; side++) {
		float sgn = side == 0 ? 1.0 : -1.0;
		float span = side == 0 ? back * L : fwd * L;
		float stp = max(span / float(STEPS - 1), 0.5);
		vec2 q = p;
		vec2 d = f0.xy;
		for (int i = 0; i < STEPS; i++) {
			float t = float(i) * stp;
			if (t > span + 0.01) {
				break;
			}
			if (!(side == 1 && i == 0)) {
				for (int layer = 0; layer < 2; layer++) {
					float S = layer == 0 ? S1 : S1 * 1.37;
					vec2 off = layer == 0 ? vec2(0.0) : vec2(0.37, 0.71) * S;
					vec2 c0 = floor((q + off) / S - 0.5);
					for (int k = 0; k < 4; k++) {
						vec2 cell = c0 + vec2(float(k & 1), float(k >> 1));
						vec3 h = kit_hash32(cell + float(layer) * 91.7);
						float pri = h.z;
						if (pri <= best_pri) {
							continue;
						}
						vec2 seed = (cell + 0.15 + 0.7 * h.xy) * S - off;
						vec2 dd = seed - q;
						float lat = dot(dd, vec2(-d.y, d.x));
						float alongq = dot(dd, d);
						float w = wbase * mix(0.65, 1.25, fract(h.z * 13.7));
						float ue = (-sgn * t - alongq) / max(L, 1e-3);
						if (ue > fwd + 0.02 || ue < -back - 0.02) {
							continue;
						}
						float end_d = min(fwd - ue, ue + back);
						float cap = sqrt(clamp(end_d * L / (0.5 * w), 0.0, 1.0));
						if (abs(lat) < 0.5 * w * cap && abs(alongq) < stp * 0.75 + 0.5) {
							best_pri = pri;
							best_seed = seed;
							best_u = ue;
							best_lat = lat / (0.5 * w);
							best_w = w;
							best_h = fract(h.x * 31.1 + h.y * 7.3);
							best_dir = d;
						}
					}
				}
			}
			vec4 fq = field_at(TEXTURE, q / out_size);
			vec2 nd = dot(fq.xy, d) < 0.0 ? -fq.xy : fq.xy;
			d = normalize(mix(d, nd, 0.6) + vec2(1e-5, 0.0));
			q += d * stp * sgn;
		}
	}
	vec3 outc;
	if (best_pri < 0.0) {
		vec3 acc = vec3(0.0);
		for (int i = 0; i < 4; i++) {
			vec2 o = (kit_hash22(p + float(i) * 7.1) - 0.5) * 4.0 * ps;
			acc += unpremul(texture(effect_tex, (p + o) / out_size), pic);
		}
		outc = acc * 0.25 * 0.94;
	} else {
		vec2 suv = best_seed / out_size;
		vec3 col = vec3(0.0);
		for (int i = -1; i <= 1; i++) {
			col += unpremul(texture(effect_tex, clamp(suv + best_dir * float(i) * best_w * 0.5 / out_size, vec2(0.0), vec2(1.0))), pic);
		}
		col /= 3.0;
		vec3 lab = kit_srgb_to_oklab(col);
		vec3 hj = kit_hash32(best_seed * 0.37 + 4.0) - 0.5;
		lab.x += hj.x * 0.08 * colour_jitter;
		lab.yz += hj.yz * 0.04 * colour_jitter;
		lab.yz *= 1.0 + 0.25 * colour_jitter;
		col = kit_oklab_to_srgb(lab);
		float lat01 = best_lat * 0.5 + 0.5;
		float br = kit_hash12(vec2(floor(lat01 * 9.0 + best_h * 50.0), best_h * 113.0));
		float br2 = kit_hash12(vec2(floor(lat01 * 23.0 + best_h * 70.0), best_h * 57.0));
		float streak = 1.0 - bristles * (0.12 * br + 0.08 * br2);
		float dry = smoothstep(-back, -back + 0.45, best_u);
		float thin = mix(1.0 - bristles * 0.35 * br, 1.0, dry);
		vec2 nrm = vec2(-best_dir.y, best_dir.x) * best_lat;
		float ridge = dot(normalize(nrm + vec2(1e-5)), normalize(vec2(-0.6, -0.8))) * abs(best_lat);
		float edge = smoothstep(0.7, 1.0, abs(best_lat));
		col *= streak;
		col = mix(pic * 0.96, col, thin);
		col *= 1.0 + relief * (0.10 * ridge - 0.08 * edge);
		outc = col;
	}
	vec2 cw = p / max(ps, 0.5);
	float weave = (sin(cw.x * 1.9) * sin(cw.y * 1.9 + sin(cw.x * 0.3))) * 0.5 + 0.5;
	outc *= 1.0 - 0.035 * relief * weave;
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
