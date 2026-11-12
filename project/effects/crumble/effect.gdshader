shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 2;
uniform float duration : hint_range(0.1, 3.0) = 0.9;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int chunks : hint_range(4, 40) = 12;
uniform vec2 impact = vec2(0.5, 0.4);
uniform float knock : hint_range(0.0, 2.0) = 0.7;
uniform float knock_angle : hint_range(-180.0, 180.0) = 90.0;
uniform float spread : hint_range(0.0, 1.0) = 0.4;
uniform float gravity : hint_range(0.0, 5.0) = 2.0;
uniform float tumble : hint_range(0.0, 1.0) = 0.5;
uniform float recede : hint_range(0.0, 3.0) = 1.0;
uniform int floor_mode : hint_range(0, 1) = 0;
uniform float settle_line : hint_range(0.0, 1.2) = 1.0;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
uniform float fade : hint_range(0.0, 1.0) = 0.3;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform int seed : hint_range(0, 9999) = 0;

float trans_amount() {
	float d = max(duration, 0.01);
	if (when == 3) {
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

vec3 nearest(vec2 q, float sd_f, float cs, out vec2 second) {
	vec2 base = floor(q / cs);
	float d1 = 1e9;
	float d2 = 1e9;
	vec2 best = base;
	second = base;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = base + vec2(float(i), float(j));
			float dd = length(q - seed_of(cell, sd_f, cs));
			if (dd < d1) {
				d2 = d1;
				second = best;
				d1 = dd;
				best = cell;
			} else if (dd < d2) {
				d2 = dd;
				second = cell;
			}
		}
	}
	return vec3(best, (d2 - d1) * 0.5);
}

float land_time(float y0, float vy, float gy, float line) {
	if (y0 >= line) {
		return 0.0;
	}
	if (gy <= 0.00001) {
		return vy > 0.00001 ? (line - y0) / vy : 1e9;
	}
	float disc = vy * vy + 2.0 * gy * (line - y0);
	if (disc < 0.0) {
		return 1e9;
	}
	return (-vy + sqrt(disc)) / gy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = trans_amount();
	vec4 bg = vec4(background.rgb * background.a, background.a);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
	vec2 sz = max(tex_size, vec2(1.0));
	float asp = sz.x / sz.y;
	vec2 asp_v = vec2(asp, 1.0);
	float sd_f = float(seed) * 3.31 + 17.0;
	float cs = asp / float(clamp(chunks, 4, 40));
	vec2 x = UV * asp_v;
	vec2 imp = clamp(impact, vec2(0.0), vec2(1.0)) * asp_v;
	float far_d = 0.0;
	far_d = max(far_d, length(imp));
	far_d = max(far_d, length(imp - vec2(asp, 0.0)));
	far_d = max(far_d, length(imp - vec2(0.0, 1.0)));
	far_d = max(far_d, length(imp - vec2(asp, 1.0)));
	float px = 1.0 / sz.y;
	float ka = radians(knock_angle);
	vec2 kdir = vec2(cos(ka), sin(ka));

	vec2 home = floor(x / cs);
	float u2c = 1.0 / cs;
	float radial = (spread * 1.6 + 0.15) * g;
	float dirx = kdir.x * knock * g;
	float diry = kdir.y * knock * g + 0.5 * gravity * g * g;
	int ixmin = int(floor((min(0.0, -dirx) - radial) * u2c)) - 1;
	int ixmax = int(ceil((max(0.0, -dirx) + radial) * u2c)) + 1;
	int jymin = int(floor((min(0.0, -diry) - radial) * u2c)) - 1;
	int jymax = int(ceil((max(0.0, -diry) + radial) * u2c)) + 1;
	int cap = 30;
	ixmin = max(ixmin, -cap);
	ixmax = min(ixmax, cap);
	jymin = max(jymin, -cap);
	jymax = min(jymax, cap);
	float best_z = 1e9;
	float next_z = 1e9;
	vec4 o = vec4(0.0);
	vec4 o2 = vec4(0.0);
	float te_front = 1.0;
	float te_next = 1.0;
	for (int j = jymin; j <= jymax; j++) {
		for (int i = ixmin; i <= ixmax; i++) {
			vec2 cell = home + vec2(float(i), float(j));
			vec2 sp = seed_of(cell, sd_f, cs);
			vec2 h = hash22(cell * 1.7 + vec2(sd_f + 5.0, 2.0));
			vec2 h2 = hash22(cell * 2.3 + vec2(sd_f + 11.0, 7.0));
			float dist_n = clamp(length(sp - imp) / max(far_d, 0.0001), 0.0, 1.0);
			float delay = dist_n * 0.4 + h.x * 0.12;
			float te = max(g - delay, 0.0);
			vec2 away = length(sp - imp) > 0.00001 ? normalize(sp - imp) : vec2(0.0, 1.0);
			vec2 jitter = (h2 - 0.5) * 0.9;
			vec2 v0 = away * spread + kdir * knock + jitter * (spread * 0.6 + 0.15);
			float gy = gravity;
			float te_eff = te;
			if (floor_mode == 1) {
				float tl = land_time(sp.y, v0.y, gy, settle_line + (h.y - 0.5) * cs * 0.6);
				te_eff = min(te, tl);
			}
			vec2 disp = v0 * te_eff + vec2(0.0, 0.5 * gy * te_eff * te_eff);
			float s = 1.0 / (1.0 + recede * te_eff);
			if (length((sp + disp) - x) > cs * 1.6 + cs * s) {
				continue;
			}
			float zdepth = recede * te_eff - disp.x * 0.001;
			if (zdepth >= next_z) {
				continue;
			}
			float ang = (h.y - 0.5) * TAU * tumble * te_eff * 1.4 + (h2.x - 0.5) * tumble * te_eff;
			vec2 l = (x - sp - disp) / max(s, 0.001);
			float cn = cos(-ang);
			float sn = sin(-ang);
			vec2 q = sp + vec2(cn * l.x - sn * l.y, sn * l.x + cn * l.y);
			vec2 runner;
			vec3 nb = nearest(q, sd_f, cs, runner);
			bool owns = nb.x == cell.x && nb.y == cell.y;
			if (!owns && (runner.x != cell.x || runner.y != cell.y)) {
				continue;
			}
			float edge_px = nb.z * s / px;
			float m = owns ? clamp(edge_px + 0.5, 0.0, 1.0) : clamp(0.5 - edge_px, 0.0, 1.0);
			if (m <= 0.0) {
				continue;
			}
			vec2 quv = q / asp_v;
			if (quv.x < 0.0 || quv.y < 0.0 || quv.x > 1.0 || quv.y > 1.0) {
				continue;
			}
			vec4 pic = texture(TEXTURE, quv);
			float a = pic.a;
			vec3 rgb = a > 0.0001 ? pic.rgb / a : vec3(0.0);
			float face = abs(cos(ang)) * 0.5 + abs(cos(ang * 1.7 + 1.0)) * 0.5;
			float lit = mix(1.0, mix(0.45, 1.1, face), shading) * (1.0 - clamp(zdepth, 0.0, 1.0) * 0.35 * shading);
			rgb = clamp(rgb * lit, 0.0, 1.0);
			float fa = 1.0;
			if (floor_mode == 0) {
				fa = 1.0 - smoothstep(0.65, 1.0, te) * fade;
			}
			vec4 piece = vec4(rgb * a, a) * m * fa;
			if (zdepth < best_z) {
				o2 = o;
				next_z = best_z;
				te_next = te_front;
				o = piece;
				best_z = zdepth;
				te_front = te_eff;
			} else {
				o2 = piece;
				next_z = zdepth;
				te_next = te_eff;
			}
		}
	}
	bool joined = te_front < 0.0001 && te_next < 0.0001;
	vec4 both = joined ? o + o2 : o + o2 * (1.0 - o.a);
	both = min(both, vec4(1.0));
	COLOR = both + bg * (1.0 - both.a);
	}
}
