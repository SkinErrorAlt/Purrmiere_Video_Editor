shader_type canvas_item;
render_mode blend_disabled;

uniform float pitch : hint_range(3.0, 60.0) = 10.0;
uniform float view_distance : hint_range(1.0, 12.0) = 1.0;
uniform int diode_type : hint_range(0, 1) = 0;
uniform float diode_size : hint_range(0.3, 1.0) = 0.62;
uniform float brightness : hint_range(0.3, 3.0) = 1.85;
uniform float unevenness : hint_range(0.0, 1.0) = 0.35;
uniform int module_size : hint_range(4, 128) = 32;
uniform float room_light : hint_range(0.0, 1.0) = 0.12;
uniform float moire : hint_range(0.0, 1.0) = 1.0;
uniform float wall_angle : hint_range(-10.0, 10.0) = 0.35;
uniform float refresh : hint_range(0.0, 1.0) = 0.0;
uniform float band_speed : hint_range(-4.0, 4.0) = 0.5;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size;
uniform float px_scale;
uniform float time;

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float spot(vec2 q, vec2 at, float s) {
	vec2 d = q - at;
	return exp(-dot(d, d) / (2.0 * s * s));
}

vec3 emit(vec2 q, vec3 c, float sz, float lit, float min_s) {
	vec3 e = vec3(0.0);
	float face = 0.012 + 0.07 * room_light;
	if (diode_type == 0) {
		float pk = 1.0 - smoothstep(-0.015, 0.015, round_box(q, vec2(0.5 * sz), 0.09 * sz));
		float s = max(0.07 * sz, min_s);
		vec3 core = vec3(spot(q, vec2(-0.15, 0.07) * sz, s), spot(q, vec2(0.0, -0.11) * sz, s), spot(q, vec2(0.15, 0.07) * sz, s));
		float diff = pk * (0.5 + 0.5 * exp(-dot(q, q) / (2.0 * 0.0625 * sz * sz)));
		e = c * (vec3(diff) * 0.8 + core * 1.1) * lit;
		float off_die = max(max(core.r, core.g), core.b);
		e += vec3(0.9, 0.86, 0.72) * room_light * (0.2 * pk + 0.45 * off_die);
		e += vec3(face) * (1.0 - pk) + vec3(0.025 + 0.05 * room_light) * pk;
	} else {
		float r = max(0.3 * sz, min_s * 1.5);
		vec2 pr = vec2(-0.21, -0.04) * min(sz, 0.7) / 0.62;
		vec2 pg = vec2(0.21, -0.04) * min(sz, 0.7) / 0.62;
		vec2 pb = vec2(0.0, 0.25) * min(sz, 0.7) / 0.62;
		vec3 dl = vec3(length(q - pr), length(q - pg), length(q - pb));
		vec3 body = 1.0 - smoothstep(vec3(r * 0.8), vec3(r * 1.05), dl);
		vec3 dome = exp(-dl * dl / (2.0 * r * r * 0.18));
		vec3 halo = exp(-dl * dl / (2.0 * r * r * 4.0));
		vec3 lamp = body * 0.6 + dome * 0.9 + halo * 0.28;
		e = c * lamp * 2.2 * lit;
		float any_body = max(max(body.r, body.g), body.b);
		e += vec3(0.75, 0.75, 0.7) * room_light * 0.25 * any_body;
		float louvre = smoothstep(-0.5, -0.38, q.y) * (1.0 - smoothstep(-0.36, -0.3, q.y));
		float ridge = smoothstep(-0.38, -0.36, q.y) * (1.0 - smoothstep(-0.36, -0.34, q.y));
		e = e * (1.0 - louvre) + vec3(face * 0.5 + room_light * 0.18 * ridge) * louvre;
		e += vec3(face) * (1.0 - any_body) * (1.0 - louvre);
	}
	return e;
}

vec3 shoulder(vec3 x) {
	vec3 over = max(x - 0.72, vec3(0.0));
	return min(x, vec3(0.72)) + 0.28 * (1.0 - exp(-over / 0.28));
}

vec3 cell_colour(sampler2D tex, vec2 cell_id, vec2 centre, float cs, float sn, float cell, out float alpha) {
	vec2 r = (cell_id + 0.5) * cell;
	float bow = 1.0 + 0.012 * dot(r, r) / max(dot(centre, centre), 1.0);
	r /= bow;
	vec2 d = vec2(cs * r.x + sn * r.y, -sn * r.x + cs * r.y);
	vec4 s = texture(tex, clamp((centre + d) / tex_size, vec2(0.0), vec2(1.0)));
	alpha = s.a;
	return s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
}

vec2 to_grid(vec2 p, vec2 centre, float cs, float sn, float cell) {
	vec2 d = p - centre;
	vec2 r = vec2(cs * d.x - sn * d.y, sn * d.x + cs * d.y);
	float bow = 1.0 + 0.012 * dot(d, d) / max(dot(centre, centre), 1.0);
	return r * bow / cell;
}

float diode_gain(vec2 id, float ch) {
	float h = hash13(vec3(id, ch + float(seed) * 3.17));
	return 1.0 + unevenness * 0.16 * (h - 0.5);
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float a = src.a;
	vec2 size = max(tex_size, vec2(1.0));
	float cell = max(pitch * max(px_scale, 0.0001) / max(view_distance, 1.0), 0.35);
	vec2 centre = size * 0.5;
	float ang = radians(wall_angle);
	float cs = cos(ang);
	float sn = sin(ang);
	vec2 p = UV * size;
	float sz = diode_size;
	float box = mix(2.4, 1.15, moire);
	float min_s = 0.5 / cell;
	float s_die = max(0.07 * sz, min_s);
	float r_lamp = max(0.3 * sz, min_s * 1.5);
	float cover = diode_type == 0 ? 0.8 * 0.64 * sz * sz + 1.1 * 6.2832 * s_die * s_die : 2.2 * (0.6 * 3.1416 * r_lamp * r_lamp * 0.85 + 0.9 * 6.2832 * r_lamp * r_lamp * 0.18);
	float comp = mix(1.0, clamp(0.42 / max(cover, 0.01), 1.0, 3.0), 1.0 - smoothstep(1.5, 6.0, cell));
	float lit_gain = brightness * comp;
	vec2 off_r = vec2(-0.25, 0.25);
	vec2 off_b = vec2(0.25, -0.25);
	float msz = float(max(module_size, 1));
	vec3 acc = vec3(0.0);
	for (int j = 0; j < 3; j++) {
		for (int i = 0; i < 3; i++) {
			vec2 sp = p + (vec2(float(i), float(j)) - 1.0) * (box / 3.0);
			vec2 g = to_grid(sp, centre, cs, sn, cell);
			vec2 id = floor(g);
			float ca = 0.0;
			vec3 c = cell_colour(TEXTURE, id, centre, cs, sn, cell, ca);
			vec2 mid = floor(id / msz);
			float mh = hash13(vec3(mid, 7.0 + float(seed)));
			vec3 mtint = vec3(hash13(vec3(mid, 11.0)), hash13(vec3(mid, 13.0)), hash13(vec3(mid, 17.0))) - 0.5;
			vec3 gain = vec3(diode_gain(id, 1.0), diode_gain(id, 2.0), diode_gain(id, 3.0));
			gain *= 1.0 + unevenness * (0.16 * (mh - 0.5) + 0.05 * mtint);
			vec3 lit = c * ca * gain;
			vec2 gr = to_grid(sp + off_r, centre, cs, sn, cell);
			vec2 gb = to_grid(sp + off_b, centre, cs, sn, cell);
			vec3 er = emit(fract(gr) - 0.5, lit, sz, lit_gain, min_s);
			vec3 eg = emit(fract(g) - 0.5, lit, sz, lit_gain, min_s);
			vec3 eb = emit(fract(gb) - 0.5, lit, sz, lit_gain, min_s);
			vec3 e = vec3(er.r, eg.g, eb.b);
			vec2 mq = abs(fract(g / msz) - 0.5) * msz;
			float seam = smoothstep(msz * 0.5 - 0.06, msz * 0.5, max(mq.x, mq.y));
			e *= 1.0 - seam * unevenness * 0.8;
			acc += e;
		}
	}
	acc /= 9.0;
	float flat_w = (1.0 - moire) * (1.0 - smoothstep(1.2, 4.0, cell));
	vec3 straight = a > 0.0001 ? src.rgb / a : vec3(0.0);
	vec3 flat_v = straight * a * brightness * 0.85 + vec3(0.03 + 0.07 * room_light);
	vec3 led = mix(acc, flat_v, flat_w);
	if (refresh > 0.0) {
		float ph = p.y / size.y * 2.7 + time * band_speed + float(seed) * 0.37;
		float band = smoothstep(0.0, 0.18, fract(ph)) * (1.0 - smoothstep(0.42, 0.62, fract(ph)));
		float fine = 0.5 + 0.5 * sin(p.y / max(cell, 1.0) * 3.1416);
		led *= 1.0 - refresh * (0.62 * band + 0.08 * band * fine);
	}
	vec3 hot = max(led - 1.0, vec3(0.0));
	float spill = (hot.r + hot.g + hot.b) * 0.03;
	vec3 tone = min(shoulder(led) + vec3(spill), vec3(1.0));
	COLOR = vec4(tone * a, a);
}
