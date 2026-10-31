shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int count : hint_range(4, 160) = 45;
uniform float size : hint_range(10.0, 300.0) = 90.0;
uniform float spread : hint_range(0.0, 1.0) = 0.6;
uniform int shape = 0;
uniform int colour_source = 0;
uniform float drift : hint_range(0.0, 1.0) = 0.4;
uniform float defocus : hint_range(0.0, 80.0) = 26.0;
uniform float intensity : hint_range(0.0, 3.0) = 1.0;

const int BLUR = 48;
const float GOLDEN = 2.39996323;

vec3 to_linear(vec3 c) {
	vec3 lo = c / 12.92;
	vec3 hi = pow((max(c, vec3(0.0)) + 0.055) / 1.055, vec3(2.4));
	return mix(lo, hi, step(vec3(0.04045), c));
}

vec3 to_srgb(vec3 c) {
	vec3 lo = c * 12.92;
	vec3 hi = 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055;
	return mix(lo, hi, step(vec3(0.0031308), c));
}

vec3 fast_linear(vec3 c) {
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);
}

vec4 lin_premul(vec4 c) {
	if (c.a <= 0.0) {
		return vec4(0.0);
	}
	return vec4(to_linear(c.rgb / c.a) * c.a, c.a);
}

vec4 srgb_premul(vec4 c) {
	if (c.a <= 0.0) {
		return vec4(0.0);
	}
	return vec4(to_srgb(c.rgb / c.a) * c.a, c.a);
}

vec2 scatter(float i) {
	vec2 h = fract(sin(vec2(i * 12.9898 + 4.1, i * 78.233 + 1.7)) * 43758.5453);
	return h - 0.5;
}

vec4 both_at(vec2 uv, float w, bool need_from, bool need_to) {
	vec2 c = clamp(uv, vec2(0.0), vec2(1.0));
	vec4 v = vec4(0.0);
	if (need_from) {
		v += texture(from_tex, c) * (1.0 - w);
	}
	if (need_to) {
		v += texture(to_tex, c) * w;
	}
	return v;
}

float hex_dist(vec2 d, float turn_a) {
	vec2 q = abs(tr_rotate(d, turn_a));
	float hex = max(q.x * 0.8660254 + q.y * 0.5, q.y);
	return mix(hex, sqrt(dot(d, d)) * 0.93, 0.3);
}

vec3 palette(float h) {
	if (h < 0.3) {
		return vec3(1.0, 0.78, 0.42);
	} else if (h < 0.55) {
		return vec3(1.0, 0.6, 0.32);
	} else if (h < 0.8) {
		return vec3(1.0, 0.88, 0.7);
	}
	return vec3(1.0, 0.55, 0.5);
}

vec3 disc_light(vec2 px, float p, float e, float w, bool need_from, bool need_to) {
	vec3 acc = vec3(0.0);
	float area = frame_px.x * frame_px.y;
	float per_layer = max(float(count) / 3.0 / 0.65, 1.0);
	float cell = sqrt(area / per_layer);
	for (int layer = 0; layer < 3; layer++) {
		float depth = float(layer) / 2.0;
		float lcell = cell * (0.75 + 0.5 * depth);
		float speed = (0.08 + 0.22 * depth) * drift;
		vec2 move = vec2(0.55, -1.0) * speed * frame_px.y * (p - 0.5);
		vec2 q = (px - move) / lcell + vec2(float(layer) * 17.3, float(layer) * 5.1);
		vec2 base_cell = floor(q);
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 id = base_cell + vec2(float(i), float(j));
				vec2 hh = tr_hash2(id + float(layer) * 31.7);
				float h3 = tr_hash(id * 1.37 + 11.0 + float(layer));
				if (h3 > 0.65) {
					continue;
				}
				vec2 centre = id + 0.15 + 0.7 * hh;
				float vary = mix(1.0, 0.45 + 0.9 * fract(h3 * 7.31), spread);
				float r_full = min(size * px_scale * (0.55 + 0.6 * depth) * vary, 0.95 * lcell);
				float t0 = 0.08 + 0.3 * fract(h3 * 3.7);
				float t1 = 0.92 - 0.3 * fract(h3 * 5.3);
				float life = smoothstep(t0 - 0.12, t0 + 0.15, p) * (1.0 - smoothstep(t1 - 0.15, t1 + 0.12, p));
				if (life <= 0.0) {
					continue;
				}
				float r = r_full * (0.55 + 0.45 * e) * (0.7 + 0.3 * life);
				vec2 d = (q - centre) * lcell;
				float dist = shape == 1 ? hex_dist(d, h3 * 6.0) : sqrt(dot(d, d));
				float x = dist / r;
				float soft = 0.07 + 0.3 * depth;
				float edge = 1.0 - smoothstep(1.0 - soft, 1.0, x);
				if (edge <= 0.0) {
					continue;
				}
				float ring = exp(-pow((x - (0.92 - soft * 0.45)) / (0.05 + soft * 0.2), 2.0));
				float onion = 0.06 * sin(x * 26.0 + h3 * 40.0) * (1.0 - x) * (1.0 - depth);
				float rim = 0.72 + 1.0 * ring * (1.0 - 0.25 * depth) + onion;
				vec2 cuv = (centre * lcell + move - vec2(float(layer) * 17.3, float(layer) * 5.1) * lcell) / frame_px;
				vec2 rr = vec2(r_full * 0.45) / frame_px;
				vec3 pc = both_at(cuv, w, need_from, need_to).rgb;
				pc += both_at(cuv + vec2(rr.x, 0.0), w, need_from, need_to).rgb;
				pc += both_at(cuv - vec2(rr.x, 0.0), w, need_from, need_to).rgb;
				pc += both_at(cuv + vec2(0.0, rr.y), w, need_from, need_to).rgb;
				pc += both_at(cuv - vec2(0.0, rr.y), w, need_from, need_to).rgb;
				pc *= 0.2;
				float pl = max(max(pc.r, max(pc.g, pc.b)), 0.0001);
				vec3 col;
				if (colour_source == 0) {
					col = fast_linear(mix(vec3(1.0), pc / pl, 0.8)) * smoothstep(0.3, 0.85, pl) * 1.3;
				} else {
					col = fast_linear(palette(fract(h3 * 13.1))) * (0.7 + 0.6 * smoothstep(0.1, 0.8, pl));
				}
				float energy = pow(60.0 * px_scale / max(r, 1.0), 0.8);
				acc += col * edge * rim * life * energy * (0.35 + 0.15 * depth);
			}
		}
	}
	return acc;
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float k = clamp((p - 0.3) / 0.4, 0.0, 1.0);
	float w = k * k * (3.0 - 2.0 * k);
	float sn = sin(TR_PI * p);
	float e = sn * sn;
	vec4 a = from_at(uv);
	vec4 b = to_at(uv);
	if (e <= 0.0) {
		return mix(a, b, w);
	}
	bool need_from = w < 1.0;
	bool need_to = w > 0.0;
	float radius = defocus * px_scale * e;
	vec4 base;
	if (radius < 0.3) {
		base = mix(a, b, w);
	} else {
		mat2 turn = mat2(vec2(cos(GOLDEN), sin(GOLDEN)), vec2(-sin(GOLDEN), cos(GOLDEN)));
		vec2 dir = vec2(1.0, 0.0);
		vec4 acc = vec4(0.0);
		for (int i = 0; i < BLUR; i++) {
			float f = (float(i) + 0.5) / float(BLUR);
			vec2 o = (dir * sqrt(f) + scatter(float(i) + 3.0) * 1.4 / sqrt(float(BLUR))) * radius;
			acc += both_at(uv + o / frame_px, w, need_from, need_to);
			dir = turn * dir;
		}
		base = acc / float(BLUR);
		vec4 sharp = mix(a, b, w);
		base = mix(sharp, base, smoothstep(0.3, 3.0, radius));
	}
	vec4 lb = lin_premul(base);
	vec3 light = disc_light(uv * frame_px, p, e, w, need_from, need_to) * intensity * e;
	vec3 lit = lb.rgb + (vec3(1.0) - min(lb.rgb, vec3(1.0))) * (vec3(1.0) - exp(-light));
	float alpha = clamp(max(lb.a, max(lit.r, max(lit.g, lit.b))), 0.0, 1.0);
	return srgb_premul(vec4(min(lit, vec3(alpha)), alpha));
}

void fragment() {
	COLOR = transition(UV);
}
