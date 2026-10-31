shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int rays = 0;
uniform float length : hint_range(10.0, 1000.0) = 420.0;
uniform float threshold : hint_range(0.0, 1.0) = 0.85;
uniform float angle : hint_range(-180.0, 180.0) = 30.0;
uniform float turn : hint_range(-180.0, 180.0) = 20.0;
uniform float dispersion : hint_range(0.0, 1.0) = 0.25;
uniform float intensity : hint_range(0.0, 4.0) = 1.5;
uniform float glints : hint_range(0.0, 1.0) = 0.35;


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

vec3 bright_part(vec3 c, float t) {
	float l = max(c.r, max(c.g, c.b));
	float hot = clamp((l - t) / max(1.0 - t, 0.02), 0.0, 1.0);
	return c * c * (hot * hot * hot * 1.6);
}

vec3 source_at(vec2 at, float w, bool need_from, bool need_to, float t) {
	vec2 uv = at / frame_px;
	if (!tr_inside(uv)) {
		return vec3(0.0);
	}
	vec3 c = vec3(0.0);
	if (need_from) {
		c += bright_part(texture(from_tex, uv).rgb, t) * (1.0 - w);
	}
	if (need_to) {
		c += bright_part(texture(to_tex, uv).rgb, t) * w;
	}
	return c;
}

vec3 spectrum(float u) {
	vec3 c = clamp(abs(fract(u * 1.3 + vec3(0.0, 0.6667, 0.3333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return c * 1.6 / max(dot(c, vec3(0.2126, 0.7152, 0.0722)) + 0.6, 0.2);
}

vec3 segment(vec2 pos, vec2 d, float len, float t0, float t1, float step_px, float fade_in0, float fade_in1, float fade_out0, float fade_out1, float w, bool need_from, bool need_to, float t) {
	float proj = dot(pos, d);
	float f = mod(proj, step_px);
	float k0 = ceil((t0 - f) / step_px);
	float k1 = floor((t1 - f) / step_px);
	vec3 acc = vec3(0.0);
	float ref = 18.0 * px_scale;
	for (float k = k0; k <= k1; k += 1.0) {
		float along = f + k * step_px;
		if (along <= 0.0) {
			continue;
		}
		float s = along / len;
		float fall = (1.0 - s) * (1.0 - s) * smoothstep(fade_in0, fade_in1, along) * (1.0 - smoothstep(fade_out0, fade_out1, along));
		if (fall <= 0.0) {
			continue;
		}
		vec3 tint = mix(vec3(1.0), spectrum(s), dispersion * smoothstep(0.05, 0.6, s));
		acc += source_at(pos - d * along, w, need_from, need_to, t) * tint * (fall * min(step_px / ref, 1.0));
	}
	return acc;
}

vec3 arm(vec2 pos, vec2 d, float len, float density, float w, bool need_from, bool need_to, float t) {
	float base_step = max(px_scale * 5.0, 1.0) * density;
	float a = 0.15 * len;
	float b = 0.1 * len;
	float c = 0.42 * len;
	float e = 0.34 * len;
	vec3 acc = segment(pos, d, len, 0.0, a, base_step, -1.0, 0.0, b, a, w, need_from, need_to, t);
	acc += segment(pos, d, len, b, c, base_step * 2.0, b, a, e, c, w, need_from, need_to, t);
	acc += segment(pos, d, len, e, len, base_step * 4.0, e, c, len * 2.0, len * 3.0, w, need_from, need_to, t);
	return acc;
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float k = clamp((p - 0.35) / 0.3, 0.0, 1.0);
	float w = k * k * (3.0 - 2.0 * k);
	float sn = sin(TR_PI * p);
	float e = sn * sn;
	vec4 a = from_at(uv);
	vec4 b = to_at(uv);
	if (e <= 0.0 || intensity <= 0.0) {
		return mix(a, b, w);
	}
	vec4 base = mix(lin_premul(a), lin_premul(b), w);
	float t = threshold;
	int count = rays == 2 ? 8 : (rays == 1 ? 6 : 4);
	float len = max(length * px_scale * (0.25 + 0.75 * e), 1.0);
	float spin = radians(angle + turn * (p - 0.5));
	vec3 star = vec3(0.0);
	vec2 pos = uv * frame_px;
	bool need_from = w < 1.0;
	bool need_to = w > 0.0;
	float density = float(count) / 4.0;
	for (int k2 = 0; k2 < count; k2++) {
		float th = spin + 6.2831853 * float(k2) / float(count);
		star += arm(pos, vec2(cos(th), -sin(th)), len, density, w, need_from, need_to, t);
	}
	if (glints > 0.0) {
		for (int k2 = 0; k2 < 4; k2++) {
			float th = spin + TR_PI / float(count) + 1.5707963 * float(k2);
			star += arm(pos, vec2(cos(th), -sin(th)), len * 0.22, 1.0, w, need_from, need_to, t) * glints * 0.7;
		}
	}
	vec3 light = star * intensity * e;
	vec3 lit = base.rgb + (vec3(1.0) - min(base.rgb, vec3(1.0))) * (vec3(1.0) - exp(-light));
	float alpha = clamp(max(base.a, max(lit.r, max(lit.g, lit.b))), 0.0, 1.0);
	return srgb_premul(vec4(min(lit, vec3(alpha)), alpha));
}

void fragment() {
	COLOR = transition(UV);
}
