shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int mode = 0;
uniform int strips : hint_range(2, 60) = 16;
uniform float particle_size : hint_range(4.0, 80.0) = 22.0;
uniform float stagger : hint_range(0.0, 1.0) = 0.5;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
uniform float twist : hint_range(0.0, 2.0) = 1.0;
uniform float curl : hint_range(0.0, 2.0) = 1.0;
uniform float thickness : hint_range(0.0, 20.0) = 5.0;
uniform vec4 paper : source_color = vec4(0.93, 0.92, 0.89, 1.0);

const vec3 KEY_LIGHT = vec3(-0.75, 0.25, -0.62);

vec4 lay(vec4 top, float cov, vec4 under, float leak) {
	return top * cov + under * (1.0 - cov + cov * (1.0 - top.a) * leak);
}

vec4 lay_w(vec4 weighted, float cov, vec4 under, float leak) {
	return weighted + under * (1.0 - cov + max(cov - weighted.a, 0.0) * leak);
}

float lit(vec3 n, float amount) {
	float diff = max(dot(normalize(n), normalize(KEY_LIGHT)), 0.0);
	return mix(1.0, mix(1.0, 0.5 + 0.62 * diff, shading), amount);
}

vec4 paper_col(float a) {
	return vec4(paper.rgb * paper.a, paper.a) * a;
}

vec4 strip_layer(vec2 uv, float t, bool arriving, out float cov) {
	cov = 0.0;
	float n = float(max(strips, 2));
	float ratio = tr_ratio();
	float sw = ratio / n;
	float th = thickness * px_scale / max(frame_px.y, 1.0);
	float x = (uv.x - 0.5) * ratio;
	float home_i = floor(clamp(uv.x, 0.0, 0.99999) * n);
	float best_z = 1e9;
	vec4 col = vec4(0.0);
	for (int k = -1; k <= 1; k++) {
		float i = home_i + float(k);
		if (i < 0.0 || i >= n) {
			continue;
		}
		float sgn = mod(i, 2.0) < 0.5 ? -1.0 : 1.0;
		float max_delay = stagger * 0.6;
		float delay = stagger * 0.45 * (i / max(n - 1.0, 1.0)) + stagger * 0.15 * tr_hash(vec2(i, 2.3));
		float s = clamp((t - delay) / (1.0 - max_delay), 0.0, 1.0);
		float off;
		float motion;
		if (arriving) {
			float e = 1.0 - pow(1.0 - s, 3.0);
			off = sgn * (1.0 - e) * 1.08;
			motion = 1.0 - e;
		} else {
			off = sgn * s * s * s * 1.08;
			motion = s;
		}
		if (motion <= 0.0 && k != 0) {
			continue;
		}
		float v = uv.y - off;
		if (v < 0.0 || v > 1.0) {
			continue;
		}
		vec3 rnd = vec3(tr_hash2(vec2(i, 5.7)), tr_hash(vec2(i, 9.1)));
		float vl = v - 0.5;
		float amt = sin(TR_PI * 0.5 * clamp(motion * 1.6, 0.0, 1.0));
		float phi = amt * twist * ((rnd.x - 0.5) * 2.4 + (rnd.y - 0.5) * 5.0 * vl);
		float sway = amt * curl * (rnd.z - 0.5) * 0.5 * sw * (1.0 + 6.0 * vl * vl) + amt * curl * 0.35 * sw * sin(vl * 6.0 + rnd.x * 6.283);
		float slope = amt * curl * (rnd.y - 0.5) * 1.6 * vl;
		float centre = (i + 0.5) * sw - ratio * 0.5 + sway;
		float e = x - centre;
		float c = cos(phi);
		float sn = sin(phi);
		float hw = sw * 0.5;
		float ht = th * 0.5;
		float pick_z = 1e9;
		float pick_a = 0.0;
		int pick_face = -1;
		if (abs(c) > 1e-4) {
			float a = (e - ht * sn) / c;
			float z = a * sn - ht * c;
			if (abs(a) <= hw && z < pick_z) {
				pick_z = z;
				pick_a = a;
				pick_face = 0;
			}
			a = (e + ht * sn) / c;
			z = a * sn + ht * c;
			if (abs(a) <= hw && z < pick_z) {
				pick_z = z;
				pick_a = a;
				pick_face = 1;
			}
		}
		if (abs(sn) > 1e-4) {
			for (int sd = 0; sd < 2; sd++) {
				float a = sd == 0 ? hw : -hw;
				float b = (a * c - e) / sn;
				float z = a * sn + b * c;
				if (abs(b) <= ht && z < pick_z) {
					pick_z = z;
					pick_a = a;
					pick_face = 2 + sd;
				}
			}
		}
		if (pick_face < 0 || pick_z >= best_z) {
			continue;
		}
		vec2 src = vec2(((i + 0.5) * sw + pick_a) / ratio, v);
		vec3 nrm;
		vec4 pc;
		if (pick_face == 0) {
			nrm = vec3(sn, slope, -c);
			pc = arriving ? to_at(src) : from_at(src);
		} else if (pick_face == 1) {
			nrm = vec3(-sn, slope, c);
			pc = paper_col((arriving ? to_at(src) : from_at(src)).a);
		} else {
			float sgn_a = pick_face == 2 ? 1.0 : -1.0;
			nrm = vec3(c * sgn_a, slope, sn * sgn_a);
			pc = paper_col((arriving ? to_at(src) : from_at(src)).a) * 0.92;
		}
		if (dot(nrm, vec3(0.0, 0.0, 1.0)) > 0.0) {
			nrm = -nrm;
		}
		col = tr_shade(pc, lit(nrm, clamp(motion * 4.0, 0.0, 1.0)));
		best_z = pick_z;
		cov = 1.0;
	}
	return col;
}

float particle_life(float ang, float t, int layer) {
	float n = tr_noise(vec2(cos(ang), sin(ang)) * 2.0 + vec2(float(layer) * 5.3, 1.1));
	float spread = stagger * 0.5;
	float delay = spread * n + float(layer) * stagger * 0.08;
	float span = 1.0 - spread - stagger * 0.16;
	return clamp((t - delay) / max(span, 0.05), 0.0, 1.0);
}

mat3 axis_turn(vec3 axis, float a) {
	vec3 k = normalize(axis);
	float c = cos(a);
	float s = sin(a);
	float t = 1.0 - c;
	return mat3(
		vec3(t * k.x * k.x + c, t * k.x * k.y + s * k.z, t * k.x * k.z - s * k.y),
		vec3(t * k.x * k.y - s * k.z, t * k.y * k.y + c, t * k.y * k.z + s * k.x),
		vec3(t * k.x * k.z + s * k.y, t * k.y * k.z - s * k.x, t * k.z * k.z + c));
}

vec4 particle_layer(vec2 w, float t, bool use_from, out float cov) {
	cov = 0.0;
	if (t <= 0.0) {
		cov = 1.0;
		return use_from ? from_at(tr_frame_uv(w)) : to_at(tr_frame_uv(w));
	}
	float ts = max(particle_size * px_scale, 1.0) / max(frame_px.y, 1.0);
	float reach = length(vec2(tr_ratio() * 0.5, 0.5));
	float travel = reach * 1.6;
	vec2 half_frame = vec2(tr_ratio() * 0.5, 0.5);
	float px_world = 1.0 / max(frame_px.y, 1.0);
	vec4 top_c = vec4(0.0);
	float top_v = 0.0;
	float top_z = 1e9;
	vec4 und_c = vec4(0.0);
	float und_v = 0.0;
	float und_z = 1e9;
	float r = length(w);
	float ang = atan(w.y, w.x);
	vec2 dir = r > 0.000001 ? w / r : vec2(1.0, 0.0);
	for (int layer = 0; layer < 3; layer++) {
		float s0 = particle_life(ang, t, layer);
		float rh = r - travel * s0 * s0;
		if (rh < -ts * 2.0) {
			continue;
		}
		vec2 base = floor(dir * rh / ts);
		for (int dy = -1; dy <= 1; dy++) {
			for (int dx = -1; dx <= 1; dx++) {
				vec2 cell = base + vec2(float(dx), float(dy));
				if (int(floor(tr_hash(cell + vec2(2.0, 13.0)) * 3.0)) != layer) {
					continue;
				}
				vec2 cc = (cell + 0.5) * ts;
				float s = particle_life(atan(cc.y, cc.x), t, layer);
				if (s >= 0.999) {
					continue;
				}
				float lc = length(cc);
				vec2 cd = lc > 0.000001 ? cc / lc : vec2(1.0, 0.0);
				vec3 pos = vec3(cc + cd * travel * s * s, -0.4 * s);
				vec3 rnd = vec3(tr_hash2(cell + vec2(7.0, 1.0)), tr_hash(cell + vec2(4.0, 6.0)));
				float turn = TR_PI * (1.0 + 2.0 * rnd.x) * s;
				mat3 rot = axis_turn(vec3(cos(rnd.y * 6.283), sin(rnd.y * 6.283), rnd.z - 0.5), turn);
				vec3 nrm = rot * vec3(0.0, 0.0, 1.0);
				if (abs(nrm.z) < 1e-4) {
					continue;
				}
				float scale = 1.0 - 0.6 * s;
				float z = pos.z - (nrm.x * (w.x - pos.x) + nrm.y * (w.y - pos.y)) / nrm.z;
				if (z >= top_z && z >= und_z) {
					continue;
				}
				vec3 local = transpose(rot) * (vec3(w, z) - pos) / scale;
				vec2 home = cc + local.xy;
				vec2 in_frame = half_frame - abs(home);
				float edge = min(min(ts * 0.5 - abs(local.x), ts * 0.5 - abs(local.y)), min(in_frame.x, in_frame.y));
				float moving = smoothstep(0.0, 0.1, s);
				float px_local = px_world / max(scale * abs(nrm.z), 0.05);
				float cv = moving > 0.0 ? clamp(edge / (px_local * moving) + 0.5, 0.0, 1.0) : (edge >= 0.0 ? 1.0 : 0.0);
				if (cv <= 0.0) {
					continue;
				}
				vec2 huv = tr_frame_uv(home);
				vec4 pc = use_from ? from_at(huv) : to_at(huv);
				vec3 nf = nrm.z > 0.0 ? -nrm : nrm;
				if (nrm.z < 0.0) {
					pc = paper_col(pc.a);
				}
				pc = tr_shade(pc, lit(nf, moving));
				cv *= 1.0 - smoothstep(0.8, 1.0, s);
				if (z < top_z) {
					und_c = top_c;
					und_v = top_v;
					und_z = top_z;
					top_c = pc;
					top_v = cv;
					top_z = z;
				} else {
					und_c = pc;
					und_v = cv;
					und_z = z;
				}
			}
		}
	}
	cov = top_v + und_v * (1.0 - top_v);
	return top_c * top_v + und_c * und_v * (1.0 - top_v);
}

vec4 transition(vec2 uv) {
	float p = progress;
	float leak = clamp(min(p, 1.0 - p) * 8.0, 0.0, 1.0);
	float cov;
	if (mode == 0) {
		vec4 c = strip_layer(uv, p, true, cov);
		return lay(c, cov, from_at(uv), leak);
	} else if (mode == 1) {
		vec4 c = strip_layer(uv, p, false, cov);
		return lay(c, cov, to_at(uv), leak);
	} else if (mode == 2) {
		vec4 c = particle_layer(tr_world(uv), 1.0 - p, false, cov);
		return lay_w(c, cov, from_at(uv), leak);
	}
	vec4 c = particle_layer(tr_world(uv), p, true, cov);
	return lay_w(c, cov, to_at(uv), leak);
}

void fragment() {
	COLOR = transition(UV);
}
