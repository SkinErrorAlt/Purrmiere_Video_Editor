shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform int across : hint_range(2, 10) = 5;
uniform float span : hint_range(0.1, 2.0) = 1.6;
uniform int order = 0;
uniform float tilt : hint_range(0.0, 20.0) = 5.0;
uniform float scatter : hint_range(0.0, 0.5) = 0.16;
uniform float misalign : hint_range(0.0, 1.0) = 0.35;
uniform float border : hint_range(0.0, 0.1) = 0.03;
uniform float print_variation : hint_range(0.0, 1.0) = 0.45;
uniform float shadow : hint_range(0.0, 1.0) = 0.55;
uniform vec4 board : source_color = vec4(0.11, 0.105, 0.1, 1.0);
uniform int seed = 0;

vec4 hash4(vec2 p) {
	vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099) + float(seed) * 0.0123);
	p4 += dot(p4, p4.wzxy + 33.33);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

struct Photo {
	vec2 centre;
	vec2 half_size;
	float angle;
	float z;
};

Photo photo_of(ivec2 cell, vec2 cell_size, vec2 size) {
	vec4 h = hash4(vec2(cell) + vec2(17.0, 31.0));
	vec4 g = hash4(vec2(cell) * 1.7 + vec2(5.0, 11.0));
	Photo ph;
	ph.centre = (vec2(cell) + 0.5 + (h.xy - 0.5) * scatter) * cell_size;
	float grow = 1.08 + 0.16 * g.x;
	ph.half_size = cell_size * 0.5 * grow;
	ph.angle = radians((h.z - 0.5) * 2.0 * tilt);
	ph.z = h.w;
	return ph;
}

vec2 to_local(Photo ph, vec2 p) {
	vec2 d = p - ph.centre;
	float c = cos(-ph.angle);
	float s = sin(-ph.angle);
	return vec2(c * d.x - s * d.y, s * d.x + c * d.y) / ph.half_size;
}

float inside(vec2 l, vec2 aa) {
	vec2 e = smoothstep(vec2(1.0) + aa, vec2(1.0) - aa, abs(l));
	return e.x * e.y;
}

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 p = UV * size;
	vec4 now = texture(TEXTURE, UV);
	int cols = clamp(across, 2, 10);
	int rows = max(2, int(round(float(cols) * size.y / size.x * 1.25)));
	vec2 cell_size = size / vec2(float(cols), float(rows));
	ivec2 c0 = ivec2(floor(p / cell_size));
	float best_z = -1.0;
	ivec2 best_cell = ivec2(-99);
	Photo best_ph;
	float best_cover = 0.0;
	vec2 best_l = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			ivec2 cell = c0 + ivec2(i, j);
			if (cell.x < 0 || cell.y < 0 || cell.x >= cols || cell.y >= rows) {
				continue;
			}
			Photo ph = photo_of(cell, cell_size, size);
			vec2 l = to_local(ph, p);
			vec2 aa = 1.2 / ph.half_size;
			float cov = inside(l, aa);
			if (cov > 0.001 && ph.z > best_z) {
				best_z = ph.z;
				best_cell = cell;
				best_ph = ph;
				best_cover = cov;
				best_l = l;
			}
		}
	}
	float shade = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			ivec2 cell = c0 + ivec2(i, j);
			if (cell.x < 0 || cell.y < 0 || cell.x >= cols || cell.y >= rows) {
				continue;
			}
			Photo ph = photo_of(cell, cell_size, size);
			if (ph.z <= best_z && best_cell.x > -99) {
				continue;
			}
			vec2 off = vec2(0.006, 0.009) * size.y;
			vec2 l = to_local(ph, p - off);
			vec2 soft = 0.035 * size.y / ph.half_size;
			vec2 e = smoothstep(vec2(1.0) + soft, vec2(1.0) - soft, abs(l));
			shade = max(shade, e.x * e.y);
		}
	}
	vec3 base = board.rgb;
	vec3 out_c = base;
	if (best_cell.x > -99) {
		vec4 h = hash4(vec2(best_cell) * 2.3 + vec2(3.0, 7.0));
		float t01 = h.x;
		if (order == 1) {
			t01 = (float(best_cell.x) + 0.5) / float(cols);
		} else if (order == 2) {
			t01 = (float(best_cell.y * cols + best_cell.x) + 0.5) / float(cols * rows);
		}
		float age = t01 * min(span * history_fps, float(history_count));
		float ca = best_ph.angle * (1.0 - misalign * 0.6);
		vec2 d = p - best_ph.centre;
		float cs = cos(ca - best_ph.angle);
		float sn = sin(ca - best_ph.angle);
		vec2 rd = vec2(cs * d.x - sn * d.y, sn * d.x + cs * d.y);
		float zoom = 1.0 + (h.y - 0.5) * 0.08 * misalign;
		vec2 shift = (h.zw - 0.5) * 0.06 * misalign * cell_size;
		vec2 q = (best_ph.centre + rd / zoom + shift) / size;
		q = clamp(q, vec2(0.0), vec2(1.0));
		vec4 shot = history_between(age, q, texture(TEXTURE, q));
		vec3 rgb = shot.a > 0.0001 ? shot.rgb / shot.a : vec3(0.0);
		vec4 v = hash4(vec2(best_cell) * 3.1 + vec2(13.0, 1.0));
		vec3 cast = vec3(1.0) + (v.xyz - 0.5) * vec3(0.12, 0.06, 0.12) * print_variation;
		float expo = 1.0 + (v.w - 0.5) * 0.3 * print_variation;
		rgb = clamp(rgb * cast * expo, 0.0, 1.0);
		rgb = mix(rgb, rgb * rgb * (3.0 - 2.0 * rgb), 0.35 * print_variation);
		vec2 al = abs(best_l);
		float vig = 1.0 - 0.18 * print_variation * dot(best_l, best_l) * 0.5;
		rgb *= vig;
		vec2 bw = vec2(border) * size.y / best_ph.half_size;
		vec2 px = 1.2 / best_ph.half_size;
		vec2 ie = smoothstep(vec2(1.0) - bw + px, vec2(1.0) - bw - px, al);
		float in_img = ie.x * ie.y;
		vec3 paper = vec3(0.95, 0.94, 0.9) * (0.97 + 0.03 * v.x);
		vec3 photo = mix(paper, rgb, in_img);
		vec3 under = base * (1.0 - shadow * 0.7 * shade);
		out_c = mix(under, photo * (1.0 - shadow * 0.45 * shade), best_cover);
	} else {
		out_c = base * (1.0 - shadow * 0.7 * shade);
	}
	COLOR = vec4(out_c, 1.0);
}
