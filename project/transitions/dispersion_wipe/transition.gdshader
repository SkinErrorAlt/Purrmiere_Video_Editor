shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform int timing = 1;
uniform float band : hint_range(0.04, 0.6) = 0.24;
uniform float dispersion : hint_range(0.0, 0.2) = 0.06;
uniform float streak : hint_range(0.0, 0.3) = 0.12;
uniform float glow : hint_range(0.0, 2.0) = 0.7;
uniform vec4 glow_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec2 dir_of(int d) {
	if (d == 1) {
		return vec2(-1.0, 0.0);
	} else if (d == 2) {
		return vec2(0.0, 1.0);
	} else if (d == 3) {
		return vec2(0.0, -1.0);
	} else if (d == 4) {
		return normalize(vec2(1.0, 1.0));
	} else if (d == 5) {
		return normalize(vec2(-1.0, 1.0));
	}
	return vec2(1.0, 0.0);
}

int curve_of(int t) {
	if (t == 1) {
		return 3;
	} else if (t == 2) {
		return 4;
	} else if (t == 3) {
		return 2;
	} else if (t == 4) {
		return 5;
	} else if (t == 5) {
		return 7;
	}
	return 0;
}

vec4 sample_disp(sampler2D tex, vec2 uv, vec2 nd, float amt) {
	float d = dispersion * amt;
	float s = streak * amt;
	vec3 col = vec3(0.0);
	float al = 0.0;
	const int N = 9;
	for (int i = 0; i < N; i++) {
		float tt = float(i) / float(N - 1) - 0.5;
		vec2 off = nd * (tt * s);
		vec3 rr = texture(tex, clamp(uv + off + nd * d, vec2(0.0), vec2(1.0))).rgb;
		vec4 gg = texture(tex, clamp(uv + off, vec2(0.0), vec2(1.0)));
		vec3 bb = texture(tex, clamp(uv + off - nd * d, vec2(0.0), vec2(1.0))).rgb;
		col += vec3(rr.r, gg.g, bb.b);
		al += gg.a;
	}
	return vec4(col / float(N), al / float(N));
}

vec4 transition(vec2 uv) {
	float e = tr_ease(progress, curve_of(timing));
	vec2 nd = dir_of(direction);
	vec4 bg = vec4(background.rgb * background.a, background.a);

	float b = max(band, 0.001);
	float amin = 0.5 - 0.5 * (abs(nd.x) + abs(nd.y));
	float amax = 1.0 - amin;
	float front = mix(amin - b, amax + b, e);
	float a = dot(uv - vec2(0.5), nd) + 0.5;
	float amt = exp(-pow((a - front) / (b * 0.6), 2.0));
	float w = smoothstep(front - b, front + b, a);

	vec4 inc;
	vec4 out_c;
	if (amt < 0.01) {
		inc = texture(to_tex, uv);
		out_c = texture(from_tex, uv);
	} else {
		inc = sample_disp(to_tex, uv, nd, amt);
		out_c = sample_disp(from_tex, uv, nd, amt);
	}
	vec4 base = mix(inc, out_c, w);

	float g = amt * glow;
	base.rgb += base.rgb * g * 0.55 + glow_tint.rgb * glow_tint.a * g * 0.18;
	base.a = clamp(base.a + g * 0.1, 0.0, 1.0);

	float ends = clamp(min(e, 1.0 - e) * 12.0, 0.0, 1.0);
	base = mix(mix(to_at(uv), from_at(uv), w), base, ends);

	return tr_over(base, bg);
}

void fragment() {
	COLOR = transition(UV);
}
