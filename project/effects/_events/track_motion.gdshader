shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/_events/ev.gdshaderinc"

uniform sampler2D change_tex : filter_nearest, repeat_disable;
uniform sampler2D motion_tex : filter_nearest, repeat_disable;
uniform int mode = 0;
uniform float sensitivity : hint_range(0.0, 1.0) = 0.5;
uniform float look_back = 1.0;
uniform float refractory = 0.0;
uniform float clip_time = 0.0;

float energy(sampler2D ms, int a) {
	vec4 s = ev_stat(ms, a);
	return s.a > 0.25 ? s.r : -1.0;
}

float local_energy(sampler2D ms, int a) {
	vec4 s = ev_stat(ms, a);
	return s.a > 0.25 ? (s.a - 0.5) * 2.0 : -1.0;
}

float base_level(sampler2D ms, sampler2D cs, int a, float cut_thr, out float peak) {
	float v[6];
	int n = 0;
	peak = 0.0;
	for (int k = 1; k <= 6; k++) {
		int b = a + k;
		if (b > 62) {
			break;
		}
		float e = energy(ms, b);
		if (e < 0.0) {
			break;
		}
		e = max(e, max(energy(ms, b + 1), 0.0));
		v[n] = e;
		peak = max(peak, e);
		n++;
		if (ev_is_cut(cs, b, cut_thr)) {
			break;
		}
	}
	if (n < 3) {
		return -1.0;
	}
	for (int i = 1; i < 6; i++) {
		if (i >= n) {
			break;
		}
		float x = v[i];
		int j = i - 1;
		while (j >= 0 && v[j] > x) {
			v[j + 1] = v[j];
			j--;
		}
		v[j + 1] = x;
	}
	return v[n / 2];
}

float jolt(sampler2D ms, sampler2D cs, int a, float thr_e, float cut_thr, bool need_quiet) {
	float e = energy(ms, a);
	if (e < thr_e || ev_is_cut(cs, a, cut_thr)) {
		return 0.0;
	}
	float peak;
	float base = base_level(ms, cs, a, cut_thr, peak);
	if (base < 0.0) {
		return 0.0;
	}
	if (need_quiet && peak > mix(0.03, 0.08, sensitivity)) {
		return 0.0;
	}
	float older = max(energy(ms, a + 1), energy(ms, a + 2));
	if (e < base * 2.5 + 0.05 || e < older * 1.5 + 0.03) {
		return 0.0;
	}
	return clamp((e - base * 2.5) / 0.35, 0.05, 1.0);
}

float arrival(sampler2D ms, sampler2D cs, int a, float cut_thr) {
	float le = local_energy(ms, a);
	float thr = mix(0.2, 0.06, clamp(sensitivity, 0.0, 1.0));
	if (le < thr || ev_is_cut(cs, a, cut_thr)) {
		return 0.0;
	}
	float quiet = mix(0.035, 0.1, clamp(sensitivity, 0.0, 1.0));
	float prior = 0.0;
	int n = 0;
	for (int k = 1; k <= 10; k++) {
		float p = local_energy(ms, a + k);
		if (p < 0.0 || ev_is_cut(cs, a + k - 1, cut_thr)) {
			break;
		}
		if (k >= 3) {
			prior = max(prior, p);
			n++;
		}
	}
	if (n < 6 || prior > quiet || le < prior * 2.5 + 0.03) {
		return 0.0;
	}
	return clamp(le * 2.0, 0.1, 1.0);
}

void fragment() {
	float fps = max(history_fps, 1.0);
	float cut_thr = ev_cut_threshold(0.5);
	int lim = min(int(ceil(look_back * fps)) + 1, 55);
	int born = int(floor(clip_time * fps + 0.001));
	int block = int(clamp(floor(UV.x * 4.0), 0.0, 3.0));
	vec4 outv = vec4(1.0, 0.0, 0.5, 0.5);
	if (mode == 0) {
		float st = mix(0.01, 0.05, clamp(sensitivity, 0.0, 1.0));
		vec4 runs = vec4(0.0);
		int run = 0;
		bool broken = false;
		int first_move = 62;
		for (int a = 0; a <= 61; a++) {
			float e = energy(motion_tex, a);
			if (a >= born || e < 0.0 || e > st || ev_is_cut(change_tex, a, cut_thr)) {
				first_move = a;
				break;
			}
		}
		int second = 62;
		for (int a = first_move + 1; a <= 61; a++) {
			float e = energy(motion_tex, a);
			if (a >= born || e < 0.0 || e > st || ev_is_cut(change_tex, a, cut_thr)) {
				second = a;
				break;
			}
		}
		for (int k = 0; k < 4; k++) {
			int r = k <= first_move ? first_move - k : (k <= second ? second - k : 0);
			runs[k] = float(r) / 63.0;
		}
		if (first_move < 4) {
			for (int k = 0; k < 4; k++) {
				if (k > first_move) {
					runs[k] = float(max(second - k, 0)) / 63.0;
				} else {
					runs[k] = float(first_move - k) / 63.0;
				}
			}
		}
		outv = runs;
	} else if (mode == 1 || mode == 2) {
		float thr_e = mode == 1 ? mix(0.3, 0.08, clamp(sensitivity, 0.0, 1.0)) : mix(0.16, 0.04, clamp(sensitivity, 0.0, 1.0));
		int refr = int(round(refractory * fps));
		int found = -1;
		float str = 0.0;
		for (int a = 0; a <= 54; a++) {
			if (a > lim) {
				break;
			}
			float j = mode == 2 ? arrival(motion_tex, change_tex, a, cut_thr) : jolt(motion_tex, change_tex, a, thr_e, cut_thr, false);
			if (j <= 0.0) {
				continue;
			}
			bool first = true;
			for (int b = a + 1; b <= 61; b++) {
				if (b > a + refr) {
					break;
				}
				float jb = mode == 2 ? arrival(motion_tex, change_tex, b, cut_thr) : jolt(motion_tex, change_tex, b, thr_e, cut_thr, false);
				if (jb > 0.0) {
					first = false;
					break;
				}
			}
			if (first) {
				found = a;
				str = j;
				break;
			}
		}
		if (found >= 0) {
			vec4 s = ev_stat(motion_tex, found);
			if (block == 0) {
				outv = vec4(float(found) / 63.0, str, s.gb);
			} else if (block == 1) {
				vec3 acc = vec3(0.0);
				for (int a = 0; a < 4; a++) {
					vec4 q = ev_stat(motion_tex, a);
					float w = max(q.r, 0.002) * float(4 - a);
					acc += vec3(q.gb * w, w);
				}
				outv = vec4(acc.xy / acc.z, 0.0, 1.0);
			}
		}
	} else {
		float thr_e = mix(0.24, 0.06, clamp(sensitivity, 0.0, 1.0));
		float total = 0.0;
		float best = 0.0;
		vec2 where = vec2(0.5);
		for (int a = 0; a <= 54; a++) {
			if (a > lim) {
				break;
			}
			float j = jolt(motion_tex, change_tex, a, thr_e, cut_thr, false);
			float t = float(a) / fps;
			float w = j * exp(-t / max(look_back * 0.4, 0.05));
			total += w;
			if (w > best) {
				best = w;
				where = ev_stat(motion_tex, a).gb;
			}
		}
		outv = vec4(1.0 - exp(-total * 1.6), where, 1.0);
	}
	COLOR = outv;
}
