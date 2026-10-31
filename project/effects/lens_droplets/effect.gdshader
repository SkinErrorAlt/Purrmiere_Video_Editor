shader_type canvas_item;
render_mode blend_disabled;

uniform float amount : hint_range(0.0, 1.0) = 0.4;
uniform float size : hint_range(4.0, 200.0) = 64.0;
uniform float size_spread : hint_range(0.0, 1.0) = 0.6;
uniform float refraction : hint_range(0.0, 1.0) = 0.7;
uniform float running : hint_range(0.0, 1.0) = 0.3;
uniform float speed : hint_range(0.0, 3.0) = 0.5;
uniform float shine : hint_range(0.0, 1.0) = 0.6;
uniform float mist : hint_range(0.0, 1.0) = 0.1;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec4 hash42(vec2 p) {
	vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	p4 += dot(p4, p4.wzxy + 33.33);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

vec4 fetch(sampler2D tex, vec2 pix, vec2 sz) {
	return texture(tex, clamp(pix / sz, vec2(0.0), vec2(1.0)));
}

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 pix = UV * sz;
	vec2 sk = vec2(mod(float(seed), 997.0) * 1.071 + 6.0, mod(float(seed), 991.0) * 0.613 + 2.0);
	float base_r = max(size * ps * 0.5, 1.0);
	float spread = clamp(size_spread, 0.0, 1.0);
	float best = 2.0;
	vec2 best_n = vec2(0.0);
	vec2 best_c = vec2(0.0);
	float best_r = 1.0;
	float cell = base_r * 4.4;
	vec2 cid = floor(pix / cell);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 id = cid + vec2(float(x), float(y));
			vec4 h = hash42(mod(id, 1024.0) + sk);
			if (h.x > amount) {
				continue;
			}
			float rad = base_r * mix(1.0, 0.35 + 0.65 * h.w, spread);
			vec2 ctr = (id + 0.25 + 0.5 * h.yz) * cell;
			vec2 n = (pix - ctr) / vec2(rad, rad * 0.92);
			float dd = length(n);
			if (dd < best) {
				best = dd;
				best_n = n;
				best_c = ctr;
				best_r = rad;
			}
		}
	}
	float wet = 0.0;
	float colw = base_r * 5.0;
	float col0 = floor(pix.x / colw);
	float run_share = clamp(running, 0.0, 1.0) * clamp(amount * 1.6, 0.0, 1.0);
	for (int x = -1; x <= 1; x++) {
		float col = col0 + float(x);
		vec4 h = hash42(vec2(mod(col, 2048.0), 77.0) + sk);
		if (h.x > run_share) {
			continue;
		}
		float rad = base_r * mix(0.9, 0.5 + 0.5 * h.w, spread);
		float travel = sz.y + rad * 6.0 + sz.y * 0.4;
		float fall = clip_time * max(speed, 0.0) * sz.y * 0.35 * (0.6 + 0.8 * h.z);
		float yy = mod(fall + h.w * travel, travel) - rad * 3.0;
		float wig = sin(pix.y / (rad * 6.0) + h.y * 20.0) * rad * 0.25;
		float xx = (col + 0.3 + 0.4 * h.y) * colw + wig;
		vec2 ctr = vec2(xx, yy);
		vec2 n = (pix - ctr) / vec2(rad * 0.9, rad * 1.1);
		float dd = length(n);
		if (dd < best) {
			best = dd;
			best_n = n;
			best_c = ctr;
			best_r = rad;
		}
		float trail_len = sz.y * (0.1 + 0.3 * h.z);
		float above = yy - pix.y;
		if (above > 0.0 && above < trail_len) {
			float across = abs(pix.x - xx) / (rad * 0.35);
			wet = max(wet, (1.0 - smoothstep(0.6, 1.0, across)) * (1.0 - above / trail_len));
		}
	}
	vec2 wet_off = vec2(wet * base_r * 0.25 * clamp(refraction, 0.0, 1.0), 0.0);
	vec4 bg = fetch(TEXTURE, pix + wet_off, sz);
	float ba = bg.a;
	vec3 bgc = ba > 0.0001 ? bg.rgb / ba : vec3(0.0);
	bgc = mix(bgc, vec3(dot(bgc, LUMA)) * 0.55 + 0.4, clamp(mist, 0.0, 1.0) * 0.55 * (1.0 - wet));
	bgc *= 1.0 - wet * 0.12;
	vec3 rgb = bgc;
	float a = ba;
	if (best < 1.0 + 2.0 / best_r) {
		float dd = min(best, 1.0);
		float hgt = sqrt(max(1.0 - dd * dd, 0.0));
		float rf = clamp(refraction, 0.0, 1.0);
		vec2 src = best_c - best_n * best_r * (0.3 + rf * 3.2) * (0.6 + 0.4 * hgt) + best_n * best_r * (1.0 - rf) * 0.9;
		vec4 dc = fetch(TEXTURE, src, sz);
		vec3 drop = dc.a > 0.0001 ? dc.rgb / dc.a : vec3(0.0);
		drop = drop * 1.08 + 0.03;
		float rim = smoothstep(0.62, 1.0, dd);
		drop *= 1.0 - 0.38 * rim;
		float sh = clamp(shine, 0.0, 1.0);
		vec2 hl = best_n - vec2(-0.35, -0.42);
		drop += vec3(exp(-dot(hl, hl) * 70.0)) * sh;
		vec2 low = best_n - vec2(0.12, 0.55);
		drop += vec3(exp(-dot(low, low) * 16.0)) * sh * 0.18;
		float cov = 1.0 - smoothstep(1.0 - 1.5 / best_r, 1.0 + 0.5 / best_r, best);
		rgb = mix(bgc, drop, cov);
		a = mix(ba, max(dc.a, ba), cov);
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
