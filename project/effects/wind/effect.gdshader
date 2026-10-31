shader_type canvas_item;
render_mode blend_disabled;

uniform int method = 0;
uniform int direction = 0;
uniform float streak_len : hint_range(1.0, 400.0) = 40.0;
uniform float strength : hint_range(0.0, 1.0) = 0.8;
uniform int streaks = 0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float lum(vec4 c) {
	return dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 dir = vec2(-1.0, 0.0);
	if (direction == 1) {
		dir = vec2(1.0, 0.0);
	} else if (direction == 2) {
		dir = vec2(0.0, 1.0);
	} else if (direction == 3) {
		dir = vec2(0.0, -1.0);
	}
	bool across_rows = direction >= 2;
	float row = floor((across_rows ? UV.x * dims.x : UV.y * dims.y) / ps);
	float sf = float(seed);
	vec2 so = vec2(mod(sf * 12.9898, 997.0), mod(sf * 78.233, 991.0));
	float h1 = hash12(vec2(row, 3.7) + so);
	float h2 = hash12(vec2(row, 11.3) + so);
	float h3 = hash12(vec2(row, 27.1) + so);
	float len_px = max(streak_len * ps, 0.5) * (0.35 + 0.65 * h1);
	float row_gain = 1.0;
	float gap = 0.0;
	float shape = 1.3;
	if (method == 1) {
		len_px *= 1.8;
		shape = 0.55;
	} else if (method == 2) {
		row_gain = h2 < 0.3 ? 0.0 : 0.4 + 0.6 * h3;
		gap = h2 * len_px * 0.6;
	}
	vec4 c = texture(TEXTURE, UV);
	vec4 best = c;
	float best_l = lum(c);
	float s = clamp(strength, 0.0, 1.0) * row_gain;
	if (s > 0.0) {
		for (int i = 1; i <= 48; i++) {
			float f = float(i) / 48.0;
			vec2 uv = UV - dir * (len_px * f + gap) / dims;
			if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
				break;
			}
			vec4 sm = texture(TEXTURE, uv);
			float w = pow(1.0 - f, shape) * s;
			vec4 cand = mix(c, sm, w);
			float l = lum(cand);
			if ((streaks == 0 && l > best_l) || (streaks == 1 && l < best_l)) {
				best = cand;
				best_l = l;
			}
		}
	}
	COLOR = best;
}
