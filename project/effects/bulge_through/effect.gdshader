shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.05, 3.0) = 0.4;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float amount : hint_range(0.0, 1.0) = 0.8;
uniform float size : hint_range(0.2, 2.0) = 0.6;
uniform float zoom : hint_range(0.0, 2.0) = 0.5;
uniform float fringe : hint_range(0.0, 1.0) = 0.5;
uniform int edges : hint_range(0, 1) = 0;

float trans_amount(out bool is_in) {
	float d = max(duration, 0.01);
	if (when == 3) {
		is_in = false;
		return clamp(progress, 0.0, 1.0);
	}
	float a_in = 0.0;
	float a_out = 0.0;
	if (when == 0 || when == 1) {
		a_in = clamp(1.0 - clip_time / d, 0.0, 1.0);
	}
	if (when == 0 || when == 2) {
		a_out = clamp(1.0 - (clip_duration - clip_time) / d, 0.0, 1.0);
	}
	is_in = a_in >= a_out;
	return max(a_in, a_out);
}

vec2 wrap(vec2 uv) {
	if (edges == 1) {
		return fract(uv);
	}
	vec2 m = mod(uv, 2.0);
	return clamp(mix(m, 2.0 - m, step(vec2(1.0), m)), vec2(0.0), vec2(1.0));
}

vec2 warp(vec2 rel, float k, float lz) {
	float r = length(rel);
	float rr = clamp(size, 0.2, 2.0);
	float m = 1.0 + k * exp(-(r * r) / (rr * rr) * 1.5);
	return rel / m * exp(-lz);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_in = false;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		vec2 asp = vec2(sz.x / sz.y, 1.0);
		vec2 ctr = clamp(centre, vec2(-0.5), vec2(1.5));
		float e = g * g;
		float k = clamp(amount, 0.0, 1.0) * 3.0 * e;
		float lz = clamp(zoom, 0.0, 2.0) * e;
		vec2 rel = (UV - ctr) * asp;
		float fr = clamp(fringe, 0.0, 1.0) * 0.12 * e;
		vec2 pg = warp(rel, k, lz);
		vec2 pr = warp(rel, k * (1.0 + fr * 2.0), lz * (1.0 + fr));
		vec2 pb = warp(rel, k * (1.0 - fr * 2.0), lz * (1.0 - fr));
		vec4 cg = texture(TEXTURE, wrap(ctr + pg / asp));
		vec4 cr = texture(TEXTURE, wrap(ctr + pr / asp));
		vec4 cb = texture(TEXTURE, wrap(ctr + pb / asp));
		COLOR = vec4(cr.r, cg.g, cb.b, max(cg.a, max(cr.a, cb.a)));
	}
}
