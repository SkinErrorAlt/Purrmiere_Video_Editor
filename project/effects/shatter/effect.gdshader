shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.1, 3.0) = 0.9;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 impact = vec2(0.5, 0.5);
uniform int shards : hint_range(4, 40) = 12;
uniform float fly : hint_range(0.0, 1.0) = 0.6;
uniform float spin : hint_range(0.0, 1.0) = 0.5;
uniform float shine : hint_range(0.0, 1.0) = 0.6;
uniform int seed : hint_range(0, 9999) = 0;

float trans_amount(out bool is_in) {
	float d = max(duration, 0.01);
	if (when == 3) {
		is_in = false;
		return clamp(progress, 0.0, 1.0);
	}
	float a_in = 0.0;
	float a_out = 0.0;
	if (when == 0 || when == 1) {
		a_in = clamp(1.0 - clip_time / d, 0.0, 1.0);
	}
	if (when == 0 || when == 2) {
		a_out = clamp(1.0 - (clip_duration - clip_time) / d, 0.0, 1.0);
	}
	is_in = a_in >= a_out;
	return max(a_in, a_out);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

vec2 seed_of(vec2 cell, float sd_f, float cs) {
	return (cell + 0.15 + 0.7 * hash22(cell + vec2(sd_f, sd_f * 0.7))) * cs;
}

vec3 nearest(vec2 q, float sd_f, float cs) {
	vec2 base = floor(q / cs);
	float d1 = 1e9;
	float d2 = 1e9;
	vec2 best = base;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = base + vec2(float(i), float(j));
			float dd = length(q - seed_of(cell, sd_f, cs));
			if (dd < d1) {
				d2 = d1;
				d1 = dd;
				best = cell;
			} else if (dd < d2) {
				d2 = dd;
			}
		}
	}
	return vec3(best, (d2 - d1) * 0.5);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_in = false;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float asp = sz.x / sz.y;
		vec2 asp_v = vec2(asp, 1.0);
		float sd_f = float(seed) * 3.31 + 17.0;
		float cs = asp / float(clamp(shards, 4, 40));
		vec2 x = UV * asp_v;
		vec2 imp = clamp(impact, vec2(0.0), vec2(1.0)) * asp_v;
		float far_d = 0.0;
		far_d = max(far_d, length(imp));
		far_d = max(far_d, length(imp - vec2(asp, 0.0)));
		far_d = max(far_d, length(imp - vec2(0.0, 1.0)));
		far_d = max(far_d, length(imp - vec2(asp, 1.0)));
		float crack = clamp(g / 0.2, 0.0, 1.0);
		float fly_g = clamp((g - 0.12) / 0.88, 0.0, 1.0);
		float px = 1.0 / sz.y;
		vec2 home = floor(x / cs);
		float best_t = 2.0;
		vec4 o = vec4(0.0);
		for (int j = -2; j <= 2; j++) {
			for (int i = -2; i <= 2; i++) {
				vec2 cell = home + vec2(float(i), float(j));
				vec2 sp = seed_of(cell, sd_f, cs);
				vec2 h = hash22(cell * 1.7 + vec2(sd_f + 5.0, 2.0));
				float dist_n = clamp(length(sp - imp) / max(far_d, 0.0001), 0.0, 1.0);
				float delay = dist_n * 0.55 + h.x * 0.15;
				float tl = clamp((fly_g - delay) / 0.3, 0.0, 1.0);
				if (tl >= best_t || tl >= 0.999) {
					continue;
				}
				float t = tl * tl;
				vec2 away = sp - imp;
				away = length(away) > 0.00001 ? normalize(away) : vec2(0.0, 1.0);
				vec2 disp = away * t * cs * 1.3 * clamp(fly, 0.0, 1.0) + vec2(0.0, t * cs * 0.6);
				float ang = (h.y - 0.5) * 3.1415926 * clamp(spin, 0.0, 1.0) * t * 1.6;
				float s = 1.0 - t;
				vec2 l = (x - sp - disp) / max(s, 0.001);
				float cn = cos(-ang);
				float sn = sin(-ang);
				vec2 q = sp + vec2(cn * l.x - sn * l.y, sn * l.x + cn * l.y);
				vec3 nb = nearest(q, sd_f, cs);
				if (nb.x != cell.x || nb.y != cell.y) {
					continue;
				}
				float edge_px = nb.z * s / px;
				float m = t > 0.0 ? clamp(edge_px + 0.5, 0.0, 1.0) : 1.0;
				float reached = step(dist_n, crack * 1.05);
				float line_w = 1.2 * sz.y / 1080.0 + 0.6;
				vec2 shift = (h - 0.5) * 0.006 * reached;
				vec4 pic = texture(TEXTURE, clamp(q / asp_v + shift, vec2(0.0), vec2(1.0)));
				float a = pic.a;
				vec3 rgb = a > 0.0001 ? pic.rgb / a : vec3(0.0);
				float crack_line = reached * (1.0 - smoothstep(line_w * 0.5, line_w * 1.5, edge_px)) * (1.0 - t);
				float sh = clamp(shine, 0.0, 1.0);
				rgb = mix(rgb, vec3(0.95, 0.97, 1.0), crack_line * sh * 0.85);
				rgb *= 1.0 - 0.45 * t + sh * 0.3 * (h.x - 0.5) * reached;
				rgb = mix(rgb, vec3(0.9, 0.95, 1.0), sh * 0.25 * (1.0 - smoothstep(0.0, line_w * 3.0, edge_px)) * step(0.0001, t));
				float fade = 1.0 - smoothstep(0.75, 1.0, t);
				o = vec4(clamp(rgb, 0.0, 1.0) * a, a) * m * fade;
				best_t = tl;
			}
		}
		COLOR = o;
	}
}
