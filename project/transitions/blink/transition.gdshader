shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int blinks : hint_range(1, 2) = 1;
uniform float hold : hint_range(0.0, 0.5) = 0.12;
uniform float lid_curve : hint_range(0.0, 1.0) = 0.6;
uniform float softness : hint_range(0.02, 0.4) = 0.16;
uniform float blur : hint_range(0.0, 80.0) = 28.0;
uniform vec4 colour : source_color = vec4(0.03, 0.012, 0.01, 1.0);
uniform int curve = 0;

float bl_close(float t) {
	t = clamp(t, 0.0, 1.0);
	return curve == 1 ? 1.0 - t : 1.0 - t * t * (1.5 - 0.5 * t);
}

float bl_open(float t) {
	t = clamp(t, 0.0, 1.0);
	return curve == 1 ? t : 1.0 - pow(1.0 - t, 3.0);
}

vec4 bl_blur(vec2 uv, float radius_px, bool use_to) {
	if (radius_px < 0.25) {
		return use_to ? to_at(uv) : from_at(uv);
	}
	vec4 acc = vec4(0.0);
	vec2 fp = floor(uv * frame_px);
	float spin = fract(52.9829189 * fract(dot(fp, vec2(0.06711056, 0.00583715)))) * 6.2831853;
	for (int i = 0; i < 24; i++) {
		float r = sqrt((float(i) + 0.5) / 24.0) * radius_px;
		float a = float(i) * 2.39996 + spin;
		vec2 o = vec2(cos(a), sin(a)) * r / frame_px;
		vec2 q = clamp(uv + o, vec2(0.0), vec2(1.0));
		acc += use_to ? texture(to_tex, q) : texture(from_tex, q);
	}
	return acc / 24.0;
}

vec4 transition(vec2 uv) {
	float p = progress;
	float o = 1.0;
	bool use_to = false;
	float avail = 1.0 - hold;
	if (blinks == 1) {
		float c1 = avail * 0.35;
		float o1 = c1 + hold;
		o = p < c1 ? bl_close(p / c1) : p < o1 ? 0.0 : bl_open((p - o1) / (1.0 - o1));
		use_to = p >= c1 + hold * 0.5;
	} else {
		float c1 = avail * 0.2;
		float h1 = c1 + hold * 0.5;
		float p1 = h1 + avail * 0.2;
		float c2 = p1 + avail * 0.12;
		float h2 = c2 + hold * 0.5;
		if (p < c1) {
			o = bl_close(p / c1);
		} else if (p < h1) {
			o = 0.0;
		} else if (p < p1) {
			o = 0.5 * bl_open((p - h1) / (p1 - h1));
		} else if (p < c2) {
			o = 0.5 * bl_close((p - p1) / (c2 - p1));
		} else if (p < h2) {
			o = 0.0;
		} else {
			o = bl_open((p - h2) / (1.0 - h2));
		}
		use_to = p >= c1 + hold * 0.25;
	}
	if (p <= 0.0) {
		o = 1.0;
	}
	if (p >= 1.0) {
		o = 1.0;
		use_to = true;
	}
	float s = softness;
	float ym = 0.56;
	float au = ym + s + 0.01;
	float al = 1.0 - ym + s + 0.01;
	float xn = (uv.x - 0.5) * 2.0;
	float almond = 1.0 - lid_curve * xn * xn * (1.0 - o * o * o * o);
	float yu = ym + s - o * (au + s) * almond - (1.0 - almond) * s;
	float yl = ym - s + o * (al + s) * mix(1.0, almond, 0.7) + (1.0 - almond) * s;
	float cu = 1.0 - smoothstep(yu - s, yu + s, uv.y);
	float cl = smoothstep(yl - s, yl + s, uv.y);
	float cover = 1.0 - (1.0 - cu) * (1.0 - cl);
	float rad = blur * px_scale * pow(1.0 - o, 0.8);
	vec4 pic = bl_blur(uv, rad, use_to);
	vec4 lid = vec4(colour.rgb * colour.a, colour.a);
	return mix(pic, lid, cover);
}

void fragment() {
	COLOR = transition(UV);
}
