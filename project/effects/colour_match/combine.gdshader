shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D src_mean : filter_nearest, repeat_disable;
uniform sampler2D src_spread : filter_nearest, repeat_disable;
uniform sampler2D ref_mean : filter_nearest, repeat_disable;
uniform sampler2D ref_spread : filter_nearest, repeat_disable;
uniform float match_brightness : hint_range(0.0, 1.0) = 1.0;
uniform float match_contrast : hint_range(0.0, 1.0) = 1.0;
uniform float match_colour : hint_range(0.0, 1.0) = 1.0;

const float GRID_X = 8.0;
const float GRID_Y = 4.0;
const float ZERO = 128.0 / 255.0;

vec3 decode_mean(vec4 t) {
	return vec3(t.r, (t.g - 0.5) * 0.5, (t.b - 0.5) * 0.5);
}

vec3 decode_spread(vec4 t) {
	return vec3(t.r * 0.5, t.g * 0.25, t.b * 0.25);
}

void gather(sampler2D means, sampler2D spreads, out vec3 mu, out vec3 sd, out float cover) {
	vec3 msum = vec3(0.0);
	vec3 vsum = vec3(0.0);
	float wsum = 0.0;
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 8; i++) {
			vec2 uv = (vec2(float(i), float(j)) + 0.5) / vec2(GRID_X, GRID_Y);
			vec4 m = textureLod(means, uv, 0.0);
			vec4 s = textureLod(spreads, uv, 0.0);
			vec3 d = decode_spread(s);
			msum += decode_mean(m) * m.a;
			vsum += d * d * m.a;
			wsum += m.a;
		}
	}
	cover = wsum / 32.0;
	mu = wsum > 0.0001 ? msum / wsum : vec3(0.5, 0.0, 0.0);
	sd = wsum > 0.0001 ? sqrt(vsum / wsum) : vec3(0.1);
}

void fragment() {
	vec3 mu_s;
	vec3 sd_s;
	float cov_s;
	vec3 mu_r;
	vec3 sd_r;
	float cov_r;
	gather(src_mean, src_spread, mu_s, sd_s, cov_s);
	gather(ref_mean, ref_spread, mu_r, sd_r, cov_r);
	vec3 gain = vec3(1.0);
	vec3 off = vec3(0.0);
	if (cov_s > 0.01 && cov_r > 0.01) {
		vec3 ratio = clamp(max(sd_r, vec3(0.004)) / max(sd_s, vec3(0.004)), vec3(0.25), vec3(4.0));
		gain = vec3(mix(1.0, ratio.x, match_contrast), mix(vec2(1.0), ratio.yz, match_colour));
		vec3 shift = (mu_r - mu_s) * vec3(match_brightness, match_colour, match_colour);
		off = mu_s * (1.0 - gain) + shift;
	}
	if (UV.x < 0.5) {
		COLOR = vec4(clamp(log2(gain) * 0.25 + ZERO, 0.0, 1.0), 1.0);
	} else {
		COLOR = vec4(clamp(vec3(off.x * 0.5, off.y, off.z) + ZERO, 0.0, 1.0), 1.0);
	}
}
