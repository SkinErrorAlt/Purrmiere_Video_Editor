shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D level_1 : filter_linear, repeat_disable;
uniform sampler2D level_2 : filter_linear, repeat_disable;
uniform sampler2D level_3 : filter_linear, repeat_disable;
uniform sampler2D level_4 : filter_linear, repeat_disable;
uniform sampler2D level_5 : filter_linear, repeat_disable;
uniform sampler2D level_6 : filter_linear, repeat_disable;
uniform sampler2D level_7 : filter_linear, repeat_disable;
uniform sampler2D level_8 : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int stage = 1;
uniform int level : hint_range(0, 2) = 0;
uniform float scale : hint_range(16.0, 250.0) = 240.0;
uniform int divisions : hint_range(1, 8) = 3;
uniform float dynamic : hint_range(0.05, 4.0) = 1.2;

const float GRID_X = 8.0;
const float GRID_Y = 4.0;
const float SIGMA_STEP = 0.96;
const float SPAN = 32.0;

vec4 cubic_sample(sampler2D tex, vec2 uv) {
	vec2 size = vec2(textureSize(tex, 0));
	vec2 p = uv * size - 0.5;
	vec2 f = fract(p);
	vec2 i = floor(p);
	vec2 f2 = f * f;
	vec2 f3 = f2 * f;
	vec2 w0 = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0;
	vec2 w1 = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
	vec2 w2 = (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0;
	vec2 w3 = f3 / 6.0;
	vec2 g0 = w0 + w1;
	vec2 g1 = w2 + w3;
	vec2 h0 = (i - 0.5 + w1 / g0) / size;
	vec2 h1 = (i + 1.5 + w3 / g1) / size;
	vec4 a = texture(tex, vec2(h0.x, h0.y));
	vec4 b = texture(tex, vec2(h1.x, h0.y));
	vec4 c = texture(tex, vec2(h0.x, h1.y));
	vec4 d = texture(tex, vec2(h1.x, h1.y));
	return g0.y * (g0.x * a + g1.x * b) + g1.y * (g0.x * c + g1.x * d);
}

vec4 level_at(int k, vec2 uv, bool smooth_up) {
	if (k <= 0) {
		return texture(effect_tex, uv);
	}
	if (k == 1) {
		return texture(level_1, uv);
	}
	if (k == 2) {
		return texture(level_2, uv);
	}
	if (k == 3) {
		return smooth_up ? cubic_sample(level_3, uv) : texture(level_3, uv);
	}
	if (k == 4) {
		return smooth_up ? cubic_sample(level_4, uv) : texture(level_4, uv);
	}
	if (k == 5) {
		return smooth_up ? cubic_sample(level_5, uv) : texture(level_5, uv);
	}
	if (k == 6) {
		return smooth_up ? cubic_sample(level_6, uv) : texture(level_6, uv);
	}
	if (k == 7) {
		return smooth_up ? cubic_sample(level_7, uv) : texture(level_7, uv);
	}
	return smooth_up ? cubic_sample(level_8, uv) : texture(level_8, uv);
}

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

vec3 blurred(float sigma, vec2 uv, bool smooth_up) {
	float lv = clamp(log2(max(sigma, 0.0001) / SIGMA_STEP), 0.0, 8.0);
	if (sigma < SIGMA_STEP * 1.0) {
		lv = clamp(sigma / SIGMA_STEP, 0.0, 1.0);
	}
	int k0 = int(floor(lv));
	int k1 = min(k0 + 1, 8);
	float t = lv - float(k0);
	vec4 a = level_at(k0, uv, smooth_up);
	vec4 b = level_at(k1, uv, smooth_up);
	return straight(mix(a, b, t));
}

float scale_at(int i, int n, float s) {
	if (n == 1) {
		return s * 0.5;
	}
	if (n == 2) {
		return i == 0 ? s * 0.5 : s;
	}
	if (level == 0) {
		return 2.0 + float(i) * s / float(n);
	}
	float step_log = log(max(s - 2.0, 1.0001)) / float(n);
	if (level == 1) {
		return 2.0 + exp(float(i) * step_log);
	}
	return s - exp(float(i) * step_log);
}

vec3 retinex_at(vec2 uv, float q, bool smooth_up) {
	vec3 src = straight(texture(effect_tex, uv)) * 255.0;
	int n = clamp(divisions, 1, 8);
	vec3 msr = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		if (i >= n) {
			break;
		}
		float sigma = scale_at(i, n, clamp(scale, 16.0, 250.0)) * q;
		vec3 b = blurred(sigma, uv, smooth_up) * 255.0;
		msr += log(src + 1.0) - log(b + 1.0);
	}
	msr /= float(n);
	float total = src.r + src.g + src.b;
	vec3 restore = log(128.0 * (src + 1.0) / (total + 3.0));
	return msr * restore;
}

vec2 encode(float v) {
	float x = clamp(v, 0.0, 0.99999) * 255.0;
	return vec2(floor(x) / 255.0, fract(x));
}

float decode(vec2 e) {
	return (e.x * 255.0 + e.y) / 255.0;
}

void fragment() {
	vec2 layer = max(vec2(textureSize(effect_tex, 0)), vec2(1.0));
	float q = max(px_scale * layer.x / max(tex_size.x, 1.0), 0.0001);
	if (stage == 0) {
		vec2 grid = vec2(GRID_X, GRID_Y);
		vec2 cell = min(floor(UV * grid), grid - 1.0);
		float sum = 0.0;
		float sum_sq = 0.0;
		for (int j = 0; j < 8; j++) {
			for (int i = 0; i < 8; i++) {
				vec2 uv = (cell + (vec2(float(i), float(j)) + 0.5) / 8.0) / grid;
				vec3 r = retinex_at(uv, q, false);
				sum += (r.r + r.g + r.b) / 3.0;
				sum_sq += dot(r, r) / 3.0;
			}
		}
		float mean = sum / 64.0;
		float mean_sq = sum_sq / 64.0;
		COLOR = vec4(encode(mean / (2.0 * SPAN) + 0.5), encode(sqrt(max(mean_sq, 0.0)) / (2.0 * SPAN)));
	} else if (stage == 2) {
		float mean = 0.0;
		float mean_sq = 0.0;
		for (int j = 0; j < 4; j++) {
			for (int i = 0; i < 8; i++) {
				vec4 e = texture(TEXTURE, (vec2(float(i), float(j)) + 0.5) / vec2(GRID_X, GRID_Y));
				mean += (decode(e.rg) - 0.5) * 2.0 * SPAN;
				float rms = decode(e.ba) * 2.0 * SPAN;
				mean_sq += rms * rms;
			}
		}
		mean /= 32.0;
		mean_sq /= 32.0;
		float sd = sqrt(max(mean_sq - mean * mean, 0.000001));
		float lo = mean - clamp(dynamic, 0.05, 4.0) * sd;
		float hi = mean + clamp(dynamic, 0.05, 4.0) * sd;
		COLOR = vec4(encode(lo / (4.0 * SPAN) + 0.5), encode(hi / (4.0 * SPAN) + 0.5));
	} else {
		vec4 e = texture(TEXTURE, vec2(0.5, 0.5));
		float lo = (decode(e.rg) - 0.5) * 4.0 * SPAN;
		float hi = (decode(e.ba) - 0.5) * 4.0 * SPAN;
		vec3 r = retinex_at(UV, q, true);
		vec3 outc = clamp((r - lo) / max(hi - lo, 0.0001), 0.0, 1.0);
		float a = texture(effect_tex, UV).a;
		COLOR = vec4(outc * a, a);
	}
}
