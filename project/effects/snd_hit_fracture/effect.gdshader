shader_type canvas_item;
render_mode blend_disabled;

#include "res://engine/sound.gdshaderinc"

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float crack_size : hint_range(0.05, 1.0) = 0.5;
uniform float min_hit : hint_range(0.0, 1.0) = 0.6;
uniform float shift : hint_range(0.0, 40.0) = 5.0;
uniform float glint : hint_range(0.0, 1.0) = 0.7;
uniform float light_angle : hint_range(-180.0, 180.0) = -40.0;
uniform float spread : hint_range(0.0, 1.0) = 0.75;
uniform vec2 centre = vec2(0.5, 0.5);
uniform int seed = 0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
const float FULL_TURN = 6.2831853;

float lin_noise(float x, float s) {
	float i = floor(x);
	return mix(snd_hash(vec2(i, s)), snd_hash(vec2(i + 1.0, s)), fract(x)) - 0.5;
}

float spoke_angle(float k, float n, float s) {
	float kk = mod(k, n);
	return (k + (snd_hash(vec2(kk * 7.13, s * 13.7)) - 0.5) * 0.55) * FULL_TURN / n;
}

float spoke_len(float k, float n, float s) {
	float kk = mod(k, n);
	return 0.45 + 0.55 * snd_hash(vec2(kk * 3.71, s * 5.3 + 1.0));
}

float kink(float r, float k, float n, float s, float l) {
	float kk = mod(k, n);
	return 0.09 * lin_noise(r / max(l, 1e-4) * 9.0, kk * 3.3 + s * 41.0) + 0.03 * lin_noise(r / max(l, 1e-4) * 31.0, kk * 1.7 + s * 23.0);
}

float ring_r(float k, float n, float s, float m) {
	float kk = mod(k, n);
	return (0.1 + m * 0.17) * (0.75 + 0.5 * snd_hash(vec2(kk * 1.91 + m * 11.0, s * 9.1)));
}

void fragment() {
	vec2 asp = vec2(tex_size.x / max(tex_size.y, 1.0), 1.0);
	vec2 p = UV * asp;
	float w = px_scale / max(tex_size.y, 1.0);
	float la = radians(light_angle);
	vec2 disp = vec2(0.0);
	float line = 0.0;
	float shine = 0.0;
	float crush = 0.0;
	float tint = 0.0;
	int n = int(snd_hits_n);
	for (int i = 0; i < 64; i++) {
		if (i >= n) {
			break;
		}
		vec4 h = snd_hit_at(i);
		if (h.x < 0.0 || h.y < min_hit) {
			continue;
		}
		float s = fract(h.z + float(seed) * 0.1317);
		vec2 rnd = snd_hash2(vec2(s * 97.0 + 3.0, s * 31.0 + 4.0));
		vec2 c = (centre + (rnd - 0.5) * spread) * asp;
		float big = smoothstep(min_hit, 1.0, h.y);
		float L = crack_size * (0.5 + 0.5 * big) * 0.75;
		float grow = 1.0 - exp(-h.x * 22.0);
		float lg = L * grow;
		vec2 d = p - c;
		float r = length(d);
		if (r > L * 1.05) {
			continue;
		}
		float nsp = 5.0 + floor(rnd.x * 5.0);
		float stp = FULL_TURN / nsp;
		float th = mod(atan(d.y, d.x) - rnd.y * FULL_TURN, FULL_TURN);
		float k = floor(th / stp);
		float a_lo = spoke_angle(k, nsp, s) + kink(r, k, nsp, s, L);
		float a_hi = spoke_angle(k + 1.0, nsp, s) + kink(r, k + 1.0, nsp, s, L);
		if (th < a_lo) {
			k -= 1.0;
			a_hi = a_lo;
			a_lo = spoke_angle(k, nsp, s) + kink(r, k, nsp, s, L);
		} else if (th > a_hi) {
			k += 1.0;
			a_lo = a_hi;
			a_hi = spoke_angle(k + 1.0, nsp, s) + kink(r, k + 1.0, nsp, s, L);
		}
		float sd = 1e5;
		float dir = th;
		for (int e = 0; e < 2; e++) {
			float kk = k + float(e);
			float a = e == 0 ? a_lo : a_hi;
			float ls = lg * spoke_len(kk, nsp, s);
			float dl = th - a;
			if (r < ls) {
				float taper = mix(1.4, 0.45, r / max(ls, 1e-5));
				float dd = r * abs(sin(dl)) / taper;
				if (dd < sd) {
					sd = dd;
					dir = a + rnd.y * FULL_TURN;
				}
			}
		}
		float rings = 0.0;
		for (int m = 0; m < 2; m++) {
			float fm = float(m);
			if (snd_hash(vec2(k * 2.3 + fm, s * 17.0)) < 0.45) {
				continue;
			}
			float r0 = ring_r(k, nsp, s, fm) * L;
			float r1 = ring_r(k + 1.0, nsp, s, fm) * L;
			if (max(r0, r1) > lg) {
				continue;
			}
			float u = clamp((th - a_lo) / max(a_hi - a_lo, 1e-4), 0.0, 1.0);
			float rr = mix(r0, r1, u * u * (3.0 - 2.0 * u));
			float dr = abs(r - rr) * 1.3;
			if (dr < sd) {
				sd = dr;
				dir = th + 1.5707963 + rnd.y * FULL_TURN;
			}
			if (r > rr) {
				rings += 1.0;
			}
		}
		float micro = 1e5;
		if (r < L * 0.16) {
			float mk = floor(th / (stp * 0.33));
			float ma = (mk + 0.5 + (snd_hash(vec2(mk, s * 3.1)) - 0.5) * 0.6) * stp * 0.33;
			micro = r * abs(sin(th - ma)) * 1.6;
		}
		float inside = 1.0 - smoothstep(lg * 0.8, lg * 1.02, r);
		vec2 piece = snd_hash2(vec2(k * 5.1 + rings * 31.0, s * 77.0 + rings));
		float fall = pow(max(1.0 - r / max(L, 1e-4), 0.0), 0.6);
		disp += (piece - 0.5) * 2.0 * shift * (0.4 + 0.6 * big) * inside * fall;
		tint += (snd_hash(vec2(k + rings * 9.0, s * 3.0)) - 0.5) * 0.07 * inside;
		float ln = (1.0 - smoothstep(w * 0.35, w * 1.6, sd)) * grow;
		ln = max(ln, (1.0 - smoothstep(w * 0.2, w * 1.0, micro)) * grow * 0.7);
		float face = pow(abs(cos(dir - la)), 5.0);
		line = max(line, ln);
		shine = max(shine, ln * (0.18 + 0.82 * face));
		crush = max(crush, (1.0 - smoothstep(L * 0.012, L * 0.045, r)) * grow * (0.5 + 0.5 * big));
	}
	vec2 uv = UV + disp * px_scale / max(tex_size, vec2(1.0));
	vec4 src = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	vec2 fj = (snd_hash2(floor(UV * tex_size / max(px_scale, 0.0001))) - 0.5) * 5.0 * px_scale / max(tex_size, vec2(1.0));
	src = mix(src, texture(TEXTURE, clamp(uv + fj, vec2(0.0), vec2(1.0))), crush);
	float a = src.a;
	vec3 rgb = a > 0.0001 ? src.rgb / a : vec3(0.0);
	rgb *= 1.0 + tint;
	rgb *= 1.0 - line * 0.3;
	rgb += (vec3(1.0) - rgb * 0.6) * shine * glint * 0.85;
	float y = dot(rgb, LUMA);
	rgb = mix(rgb, vec3(0.92) * (0.5 + 0.5 * y) + rgb * 0.2, crush * 0.75);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
