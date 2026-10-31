shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D level_4 : filter_linear, repeat_disable;
uniform sampler2D level_16 : filter_linear, repeat_disable;
uniform float threshold : hint_range(0.85, 1.0) = 0.97;
uniform float rebuild : hint_range(0.0, 1.0) = 1.0;
uniform float roll_from : hint_range(0.5, 0.95) = 0.82;
uniform float headroom : hint_range(1.05, 2.0) = 1.3;
uniform bool show = false;

const vec2 DIRS[8] = vec2[8](vec2(1.0, 0.0), vec2(0.7071, 0.7071), vec2(0.0, 1.0), vec2(-0.7071, 0.7071), vec2(-1.0, 0.0), vec2(-0.7071, -0.7071), vec2(0.0, -1.0), vec2(0.7071, -0.7071));

float roll(float x, float knee, float h) {
	if (x <= knee) {
		return x;
	}
	float span = max(h - knee, 0.0001);
	float c = (span / max(1.0 - knee, 0.0001) - 1.0) / span;
	return knee + (x - knee) / (1.0 + (x - knee) * max(c, 0.0));
}

float agree(vec3 rgb, vec3 u, vec3 r, float t) {
	float den = dot(u * r, r);
	if (den < 0.00001) {
		return 0.0;
	}
	float s = dot(u * rgb, r) / den;
	vec3 d = rgb - s * r;
	vec3 short_of = max(vec3(t) - s * r, vec3(0.0)) * (vec3(1.0) - u);
	float e = (dot(u * d, d) + dot(short_of, short_of)) / (dot(u * rgb, rgb) + 0.0001);
	return exp(-e * 400.0);
}

void fragment() {
	vec4 src = texture(effect_tex, UV);
	float a = src.a;
	vec3 rgb = a > 0.0001 ? clamp(src.rgb / a, 0.0, 1.0) : vec3(0.0);
	float t = clamp(threshold, 0.85, 1.0);
	vec3 k = smoothstep(vec3(t - 0.03), vec3(t), rgb);
	float h = clamp(headroom, 1.05, 2.0);
	vec3 u = vec3(1.0) - k;
	float any_clip = max(k.r, max(k.g, k.b));
	float all_clip = min(k.r, min(k.g, k.b));
	vec3 rebuilt = rgb;
	if (any_clip > 0.001 && all_clip < 0.999 && rebuild > 0.0) {
		vec3 ref_sum = vec3(0.0);
		float w_sum = 0.0;
		vec2 t4 = 1.0 / vec2(max(textureSize(level_4, 0), ivec2(1)));
		vec2 t16 = 1.0 / vec2(max(textureSize(level_16, 0), ivec2(1)));
		for (int d = 0; d < 8; d++) {
			for (int i = 1; i <= 12; i++) {
				vec2 p = UV + DIRS[d] * t4 * 2.0 * float(i);
				if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) {
					break;
				}
				vec4 s = texture(level_4, p);
				if (s.a > 0.3) {
					vec3 r = s.rgb / s.a;
					float w = s.a * agree(rgb, u, r, t - 0.03) / float(i);
					ref_sum += r * w;
					w_sum += w;
					break;
				}
			}
			for (int i = 1; i <= 12; i++) {
				vec2 p = UV + DIRS[d] * t16 * 1.5 * float(i);
				if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) {
					break;
				}
				vec4 s = texture(level_16, p);
				if (s.a > 0.3) {
					vec3 r = s.rgb / s.a;
					float w = 0.5 * s.a * agree(rgb, u, r, t - 0.03) / float(i * 4);
					ref_sum += r * w;
					w_sum += w;
					break;
				}
			}
		}
		vec4 far = texture(TEXTURE, UV);
		if (far.a > 0.01) {
			vec3 r = far.rgb / far.a;
			float w = 0.002 * far.a * agree(rgb, u, r, t - 0.03);
			ref_sum += r * w;
			w_sum += w;
		}
		if (w_sum > 0.000001) {
			vec3 ref = ref_sum / w_sum;
			float have = smoothstep(0.0, 0.002, w_sum);
			float den = dot(u * ref, ref);
			if (den > 0.0001) {
				float s = dot(u * rgb, ref) / den;
				vec3 est = clamp(s * ref, vec3(0.0), vec3(h));
				vec3 grown = max(rgb, est);
				rebuilt = mix(rgb, grown, k * clamp(rebuild, 0.0, 1.0) * have * (1.0 - all_clip));
			}
		}
	}
	float x = max(rebuilt.r, max(rebuilt.g, rebuilt.b));
	float x_eff = mix(x, h, all_clip);
	float y = roll(x_eff, clamp(roll_from, 0.5, 0.95), h);
	vec3 outc = x > 0.000001 ? rebuilt * (y / x) : rebuilt;
	outc = mix(outc, vec3(y), all_clip);
	if (show) {
		outc = mix(vec3(dot(rgb, vec3(0.2126, 0.7152, 0.0722)) * 0.3), k, any_clip);
	}
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
