shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int bars : hint_range(2, 30) = 8;
uniform int orientation = 0;
uniform int order = 0;
uniform float stagger : hint_range(0.0, 1.0) = 0.6;
uniform float gap : hint_range(0.0, 1.0) = 0.0;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.5;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

float lv_delay(int i, int n) {
	float f = n > 1 ? float(i) / float(n - 1) : 0.0;
	if (order == 1) {
		return 1.0 - f;
	} else if (order == 2) {
		return abs(f - 0.5) * 2.0;
	} else if (order == 3) {
		return tr_hash(vec2(float(i) * 3.17 + 1.3, 7.7));
	}
	return f;
}

float lv_angle(int i, int n) {
	float st = clamp(stagger, 0.0, 0.92);
	float local = clamp((progress - st * lv_delay(i, n)) / (1.0 - st), 0.0, 1.0);
	return 90.0 * tr_ease(local, 3);
}

vec2 lv_uv(float al, float be) {
	return orientation == 1 ? tr_frame_uv(vec2(be, al)) : tr_frame_uv(vec2(al, be));
}

vec3 lv_to_world(vec3 n, float c, float sn) {
	return vec3(n.x, n.y * c - n.z * sn, n.y * sn + n.z * c);
}

vec4 lv_trace(vec2 uv, float pad_px, bool fill, out float id) {
	float p = clamp(progress, 0.0, 1.0);
	id = -1.0;
	int n = clamp(bars, 2, 30);
	bool vert = orientation == 1;
	float ratio = tr_ratio();
	float len = vert ? 1.0 : ratio;
	float ext = vert ? ratio : 1.0;
	float h = ext / float(n);
	vec2 w = tr_world(uv);
	vec2 s = vert ? vec2(w.y, w.x) : w;
	float d = tr_camera_distance(lens);
	vec3 o = vec3(0.0, 0.0, -d);
	vec3 dir = normalize(vec3(s, d));
	vec3 light_dir = normalize(vec3(-0.35, 0.55, -1.0));
	float base_lam = dot(vec3(0.0, 0.0, -1.0), light_dir);
	int j = int(floor((ext * 0.5 - s.y) / h));
	float best = 1.0e9;
	vec4 col = vec4(0.0);
	bool hit_any = false;
	int jc = clamp(j, 0, n - 1);
	float near_mix = smoothstep(35.0, 55.0, lv_angle(jc, n));
	vec4 flat_pic = mix(from_clamped(uv), to_clamped(uv), near_mix);
	for (int k = -2; k <= 2; k++) {
		int i = j + k;
		if (i < 0 || i >= n) {
			continue;
		}
		float th = radians(lv_angle(i, n));
		float c = cos(th);
		float sn = sin(th);
		float sc = (1.0 - gap * 0.5 * sin(2.0 * th)) / (c + sn) * (fill ? 1.0 + 0.06 * (1.0 - smoothstep(0.0, 0.12, gap)) : 1.0);
		float pad = pad_px / frame_px.y;
		float hs = sc * h * 0.5 + pad;
		float bi = ext * 0.5 - h * (float(i) + 0.5);
		vec3 rel = o - vec3(0.0, bi, h * 0.5 + pad);
		vec3 ol = vec3(rel.x, rel.y * c + rel.z * sn, -rel.y * sn + rel.z * c);
		vec3 dl = vec3(dir.x, dir.y * c + dir.z * sn, -dir.y * sn + dir.z * c);
		vec3 safe = vec3(abs(dl.x) < 0.000001 ? 0.000001 : dl.x, abs(dl.y) < 0.000001 ? 0.000001 : dl.y, abs(dl.z) < 0.000001 ? 0.000001 : dl.z);
		vec3 inv = 1.0 / safe;
		vec3 half_size = vec3(len * 0.5, hs, hs);
		vec3 t1 = (-half_size - ol) * inv;
		vec3 t2 = (half_size - ol) * inv;
		vec3 tlo = min(t1, t2);
		vec3 thi = max(t1, t2);
		float tn = max(max(tlo.x, tlo.y), tlo.z);
		float tf = min(min(thi.x, thi.y), thi.z);
		if (tf < max(tn, 0.0) || tn <= 0.0 || tn >= best) {
			continue;
		}
		best = tn;
		hit_any = true;
		id = float(i * 4);
		vec3 hp = ol + dl * tn;
		vec3 nl = vec3(0.0);
		vec4 face = vec4(0.0);
		bool side = false;
		if (tn == tlo.z) {
			if (hp.z < 0.0) {
				nl = vec3(0.0, 0.0, -1.0);
				face = from_clamped(lv_uv(hp.x, bi + hp.y / sc));
			} else {
				nl = vec3(0.0, 0.0, 1.0);
				side = true;
				id += 1.0;
			}
		} else if (tn == tlo.y) {
			if (hp.y < 0.0) {
				nl = vec3(0.0, -1.0, 0.0);
				face = to_clamped(lv_uv(hp.x, bi - hp.z / sc));
				id += 2.0;
			} else {
				nl = vec3(0.0, 1.0, 0.0);
				side = true;
				id += 3.0;
			}
		} else {
			nl = vec3(sign(hp.x), 0.0, 0.0);
			side = true;
			id += 3.0;
		}
		vec3 nw = lv_to_world(nl, c, sn);
		float lam = max(dot(nw, light_dir), 0.0);
		float light = mix(1.0, clamp(lam / base_lam, side ? 0.6 : 0.45, 1.3), shading);
		if (side) {
			face = mix(from_clamped(uv), to_clamped(uv), smoothstep(35.0, 55.0, degrees(th)));
		}
		col = tr_shade(face, light);
	}
	float bg_weight = smoothstep(0.0, 0.08, p) * (1.0 - smoothstep(0.92, 1.0, p));
	vec4 bg = vec4(background.rgb * background.a, background.a) * bg_weight;
	if (hit_any) {
		return tr_over(col, bg);
	}
	float fill_w = 1.0 - smoothstep(0.0, 0.08, gap);
	return mix(bg, tr_over(flat_pic, bg), fill_w);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	if (p <= 0.0) {
		return texture(from_tex, uv);
	}
	if (p >= 1.0) {
		return texture(to_tex, uv);
	}
	float id0;
	vec4 c0 = lv_trace(uv, 0.6, false, id0);
	if (id0 < 0.0) {
		c0 = lv_trace(uv, 0.6, true, id0);
	}
	vec2 px = 1.0 / frame_px;
	vec4 acc = vec4(0.0);
	bool same = true;
	vec2 offs[4] = vec2[](vec2(0.125, 0.375), vec2(-0.375, 0.125), vec2(0.375, -0.125), vec2(-0.125, -0.375));
	for (int i = 0; i < 4; i++) {
		float idk;
		vec4 ck = lv_trace(uv + offs[i] * px, 0.6, false, idk);
		if (idk < 0.0) {
			ck = lv_trace(uv + offs[i] * px, 0.6, true, idk);
		}
		acc += ck;
		if (idk != id0) {
			same = false;
		}
	}
	return same ? c0 : acc * 0.25;
}

void fragment() {
	COLOR = transition(UV);
}
