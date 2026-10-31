shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int layers : hint_range(2, 6) = 4;
uniform float density : hint_range(0.0, 1.0) = 0.75;
uniform vec4 colour : source_color = vec4(0.97, 0.97, 1.0, 1.0);
uniform float sun_angle : hint_range(-180.0, 180.0) = 70.0;
uniform float speed : hint_range(0.5, 2.0) = 1.0;
uniform float push : hint_range(0.0, 0.5) = 0.15;

const mat2 CP_ROT = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));

float cp_fbm(vec2 q) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * tr_noise(q);
		q = CP_ROT * q * 2.03 + vec2(13.7, 7.3);
		a *= 0.5;
	}
	return v / 0.9375;
}

float cp_mass(vec2 c) {
	return tr_noise(c) * 0.62 + tr_noise(CP_ROT * c * 2.1 + vec2(5.3, 1.1)) * 0.38;
}

float cp_ero(vec2 c) {
	float v = tr_noise(c * 4.6) * 0.55;
	v += tr_noise(CP_ROT * c * 9.7 + vec2(2.0, 7.0)) * 0.3;
	v += tr_noise(c * 19.0 + vec2(9.0, 3.0)) * 0.15;
	return v;
}

vec4 transition(vec2 uv) {
	float p = progress;
	float pe = tr_ease(p, 3);
	float env_in = smoothstep(0.0, 0.22, p);
	float env = env_in * env_in * (1.0 - smoothstep(0.9, 1.0, p));
	vec2 w = tr_world(uv);
	float vel = 2.2 * speed;
	int mi = (layers - 1) / 2;
	float m = smoothstep(0.485, 0.515, p);
	float zf = 1.0 + push * pe;
	float zt = 1.0 - push * 0.6 * (1.0 - pe);
	vec4 pic;
	if (p <= 0.0) {
		pic = from_at(uv);
	} else if (p >= 1.0) {
		pic = to_at(uv);
	} else {
		vec4 a = from_mirrored(vec2(0.5) + (uv - vec2(0.5)) / zf);
		vec4 b = to_mirrored(vec2(0.5) + (uv - vec2(0.5)) / zt);
		if (p < 0.5) {
			a = mix(from_at(uv), a, smoothstep(0.0, 0.08, p));
		} else {
			b = mix(to_at(uv), b, 1.0 - smoothstep(0.92, 1.0, p));
		}
		pic = mix(a, b, m);
	}
	float sa = radians(sun_angle);
	vec2 sun = vec2(cos(sa), sin(sa));
	vec3 lit_col = min(colour.rgb * vec3(1.04, 1.01, 0.95), vec3(1.0));
	vec3 base_col = colour.rgb * vec3(0.47, 0.51, 0.61);
	float tex = cp_ero(w * 0.6 + vec2(p * 0.7, 2.0));
	vec3 haze_col = mix(colour.rgb * 0.9, lit_col, 0.6) * (0.93 + 0.12 * tex);
	float dmain = (0.5 - p) * vel;
	float veil = (1.0 - smoothstep(0.1, 1.0, abs(dmain))) * 0.35 * density * env;
	vec4 outc = mix(pic, vec4(haze_col, 1.0) * mix(pic.a, 1.0, veil), veil);
	float dmax = 1.6;
	for (int j = 5; j >= 0; j--) {
		if (j >= layers) {
			continue;
		}
		float tj = 0.5 + float(j - mi) * 0.16;
		float d = (tj - p) * vel;
		bool main_bank = j == mi;
		float fog_w = main_bank ? 1.0 - smoothstep(0.04, 0.32, abs(d)) : (1.0 - smoothstep(0.0, 0.12, abs(d))) * 0.2;
		if (d > 0.05 && d < dmax) {
			vec2 off = vec2(tr_hash(vec2(float(j), 3.0)), tr_hash(vec2(7.0, float(j)))) * 50.0;
			float bl = clamp(0.03 * vel / d, 0.0, 0.35);
			vec2 wcj = (vec2(tr_hash(vec2(float(j), 11.0)), tr_hash(vec2(13.0, float(j)))) - 0.5) * vec2(0.5, 0.3);
			vec2 rel = w - wcj;
			float ragged = 0.6 + 0.8 * tr_noise(normalize(rel + vec2(0.0001)) * 2.2 + vec2(float(j) * 7.0, float(j) * 3.0));
			float cover = density * (main_bank ? 1.0 : j > mi ? 0.55 : 0.75);
			float th = mix(0.66, 0.4, cover);
			float dens = 0.0;
			float mass0 = 0.0;
			vec2 c0 = vec2(0.0);
			for (int k = 0; k < 4; k++) {
				float f = 1.0 + bl * (float(k) / 3.0 - 0.5);
				vec2 c = (w - wcj) * d * f * 1.8 + off;
				float mass = cp_mass(c);
				float ero = cp_ero(c);
				float mm = mass + (ero - 0.5) * 0.34;
				dens += smoothstep(th, th + 0.16, mm);
				if (k == 1) {
					mass0 = mass;
					c0 = c;
				}
			}
			dens *= 0.25 * (main_bank ? 1.0 : mix(1.0, smoothstep(0.03, 0.2, length(rel) * d * ragged), 0.8));
			float mass1 = cp_mass(c0 + sun * 0.14);
			float facing = clamp(0.5 + (mass0 - mass1) * 10.0 * smoothstep(0.1, 0.5, d), 0.15, 1.0);
			float thick = smoothstep(th, th + 0.35, mass0);
			vec3 cloud = mix(base_col, lit_col, clamp(facing * (1.0 - 0.25 * thick) + 0.15, 0.0, 1.0));
			float rim = (1.0 - smoothstep(0.05, 0.6, dens)) * smoothstep(0.55, 0.9, facing);
			cloud = min(cloud + lit_col * rim * 0.3, vec3(1.0));
			float aerial = smoothstep(0.5, dmax, d) * 0.65;
			cloud = mix(cloud, haze_col, aerial);
			float vis = smoothstep(dmax, dmax * 0.65, d) * smoothstep(0.05, 0.25, d) * env * colour.a;
			float alpha = dens * vis;
			outc = vec4(cloud * alpha, alpha) + outc * (1.0 - alpha);
		}
		float fog = clamp(fog_w * (main_bank ? mix(0.9, 1.0, density) : density), 0.0, 1.0) * (0.97 + 0.03 * tex) * env * colour.a;
		vec3 fog_col = mix(haze_col, lit_col, 0.3 * tex) * (0.86 + 0.2 * cp_mass(w * 1.7 + vec2(p * 1.5, float(j) * 9.0)));
		outc = vec4(fog_col * fog, fog) + outc * (1.0 - fog);
	}
	return outc;
}

void fragment() {
	COLOR = transition(UV);
}
