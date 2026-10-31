shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float threshold : hint_range(0.0, 1.0) = 0.6;
uniform float intensity : hint_range(0.0, 4.0) = 2.0;
uniform float radius : hint_range(4.0, 400.0) = 130.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow_saturation : hint_range(0.0, 2.0) = 1.0;
uniform int curve = 1;

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

vec3 bright_part(vec4 c, float t) {
	vec3 v = pow(max(c.rgb, vec3(0.0)), vec3(1.4));
	float l = dot(v, vec3(0.2126, 0.7152, 0.0722));
	float knee = max(t * 0.4, 0.002);
	float soft = clamp(l - t + knee, 0.0, 2.0 * knee);
	float over = max(soft * soft / (4.0 * knee), l - t) / max(1.0 - t, 0.05);
	return v * (over / max(l, 0.0001)) * (0.7 + over);
}

vec3 glow_at(vec2 uv, float r, float t, float w, bool need_from, bool need_to) {
	vec3 c = vec3(0.0);
	if (need_from) {
		c += bright_part(from_blur(uv, r), t) * (1.0 - w);
	}
	if (need_to) {
		c += bright_part(to_blur(uv, r), t) * w;
	}
	return c;
}

vec3 cell_at(vec2 uv, float lod, float t, float w, bool need_from, bool need_to) {
	vec3 c = vec3(0.0);
	if (need_from) {
		c += bright_part(from_lod(uv, lod), t) * (1.0 - w);
	}
	if (need_to) {
		c += bright_part(to_lod(uv, lod), t) * w;
	}
	return c;
}

float envelope(float p) {
	if (curve == 1) {
		float s = sin(TR_PI * p);
		return s * s;
	}
	return 1.0 - abs(2.0 * p - 1.0);
}

float dissolve(float p) {
	float t = clamp((p - 0.3) / 0.4, 0.0, 1.0);
	return curve == 1 ? t * t * (3.0 - 2.0 * t) : t;
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float w = dissolve(p);
	float e = envelope(p);
	vec4 a = from_at(uv);
	vec4 b = to_at(uv);
	if (e <= 0.0 || intensity <= 0.0) {
		return mix(a, b, w);
	}
	vec4 base = mix(lin_premul(a), lin_premul(b), w);
	bool need_from = w < 1.0;
	bool need_to = w > 0.0;
	float t = pow(threshold, 1.4);
	float r_halo = max(radius * px_scale * (0.55 + 0.45 * e), 1.0);
	vec3 core = glow_at(uv, r_halo * 0.05, t, w, need_from, need_to);
	float r_full = max(radius * px_scale, 1.0);
	float lod = clamp(floor(log2(max(r_full / 10.0, 1.0)) + 0.5), 0.0, 5.0);
	float cell = exp2(lod + 1.0);
	vec2 pos = uv * frame_px;
	vec2 lo = floor((pos - r_halo) / cell);
	vec2 hi = floor((pos + r_halo) / cell);
	vec3 halo = vec3(0.0);
	float halo_w = 0.0;
	for (float j = lo.y; j <= hi.y; j += 1.0) {
		for (float i = lo.x; i <= hi.x; i += 1.0) {
			vec2 c = (vec2(i, j) + 0.5) * cell;
			vec2 d = (pos - c) / r_halo;
			float q = dot(d, d);
			if (q >= 1.0) {
				continue;
			}
			float g = (1.4 * exp(-q / 0.06) + 0.6 * exp(-q / 0.25)) * (1.0 - q) * (1.0 - q);
			halo += cell_at(c / frame_px, lod, t * 0.8, w, need_from, need_to) * g;
			halo_w += g;
		}
	}
	halo /= max(halo_w, 0.000001);
	vec3 glow = core * 1.0 + halo * 6.0;
	float gl = dot(glow, vec3(0.2126, 0.7152, 0.0722));
	glow = max(mix(vec3(gl), glow, glow_saturation), vec3(0.0));
	glow *= to_linear(tint.rgb) * intensity * e;
	vec3 lit = base.rgb + (vec3(1.0) - min(base.rgb, vec3(1.0))) * (vec3(1.0) - exp(-glow));
	float alpha = clamp(max(base.a, max(lit.r, max(lit.g, lit.b))), 0.0, 1.0);
	return srgb_premul(vec4(min(lit, vec3(alpha)), alpha));
}

void fragment() {
	COLOR = transition(UV);
}
