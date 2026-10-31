shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform bool grey_on = true;
uniform vec2 grey_point = vec2(0.5, 0.5);
uniform vec4 grey_target : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform bool black_on = false;
uniform vec2 black_point = vec2(0.1, 0.9);
uniform bool white_on = false;
uniform vec2 white_point = vec2(0.9, 0.1);
uniform float sample_size : hint_range(1.0, 40.0) = 8.0;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform bool mark = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_display(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 sample_at(vec2 centre) {
	vec2 reach = vec2(sample_size * px_scale) / tex_size;
	vec3 sum = vec3(0.0);
	float wsum = 0.0;
	for (int j = 0; j < 5; j++) {
		for (int i = 0; i < 5; i++) {
			vec2 o = (vec2(float(i), float(j)) / 4.0 - 0.5) * reach;
			vec4 s = texture(effect_tex, clamp(centre + o, vec2(0.0), vec2(1.0)));
			if (s.a > 0.01) {
				sum += s.rgb / s.a * s.a;
				wsum += s.a;
			}
		}
	}
	return wsum > 0.0001 ? sum / wsum : vec3(0.5);
}

vec3 balanced(vec3 enc, vec3 gains) {
	return to_display(to_linear(enc) * gains);
}

float ring(vec2 uv, vec2 centre) {
	vec2 d = (uv - centre) * tex_size;
	float r = length(d);
	float rad = sample_size * px_scale * 0.5 + 4.0 * px_scale;
	return 1.0 - smoothstep(0.6 * px_scale, 1.6 * px_scale, abs(r - rad));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 gains = vec3(1.0);
	if (grey_on) {
		vec3 s = max(to_linear(sample_at(grey_point)), vec3(0.0005));
		vec3 t = max(to_linear(grey_target.rgb), vec3(0.0005));
		vec3 want = t * (dot(s, LUMA) / max(dot(t, LUMA), 0.0005));
		gains = clamp(want / s, vec3(0.2), vec3(5.0));
	}
	vec3 lo = vec3(0.0);
	vec3 hi = vec3(1.0);
	if (black_on) {
		lo = balanced(sample_at(black_point), gains);
	}
	if (white_on) {
		hi = balanced(sample_at(white_point), gains);
	}
	lo = min(lo, vec3(0.6));
	hi = max(hi, lo + 0.05);
	vec3 outc = clamp((balanced(rgb, gains) - lo) / (hi - lo), 0.0, 1.0);
	outc = mix(rgb, outc, amount);
	if (mark) {
		float m = 0.0;
		if (grey_on) {
			m = max(m, ring(UV, grey_point));
		}
		if (black_on) {
			m = max(m, ring(UV, black_point));
		}
		if (white_on) {
			m = max(m, ring(UV, white_point));
		}
		outc = mix(outc, vec3(1.0, 0.85, 0.2), m);
		a = max(a, m);
	}
	COLOR = vec4(outc * a, a);
}
