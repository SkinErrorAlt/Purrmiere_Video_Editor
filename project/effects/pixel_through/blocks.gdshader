shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D level_1 : filter_linear, repeat_disable;
uniform sampler2D level_2 : filter_linear, repeat_disable;
uniform sampler2D level_3 : filter_linear, repeat_disable;
uniform sampler2D level_4 : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.05, 3.0) = 0.5;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float size : hint_range(4.0, 400.0) = 120.0;
uniform int shape : hint_range(0, 1) = 0;
uniform int steps : hint_range(0, 1) = 1;

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

vec4 level(int k, vec2 uv, sampler2D top) {
	uv = clamp(uv, vec2(0.0), vec2(1.0));
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
		return texture(level_3, uv);
	}
	if (k == 4) {
		return texture(level_4, uv);
	}
	return texture(top, uv);
}

void fragment() {
	vec2 out_px = max(fwidth(UV), vec2(0.000001));
	vec2 dims = 1.0 / out_px;
	vec4 c = texture(effect_tex, UV);
	bool is_in = false;
	float g = trans_amount(is_in);
	float ps = max(px_scale * dims.x / max(tex_size.x, 1.0), 0.0001);
	float big = max(clamp(size, 4.0, 400.0) * ps, 1.0);
	float e = g;
	if (steps == 1) {
		e = floor(g * 8.0 + 0.5) / 8.0;
	}
	float b = exp(log(big) * e);
	if (g <= 0.0001 || b < 1.5) {
		COLOR = c;
	} else {
		vec2 pix = UV * dims - 0.5 * dims;
		vec2 cuv;
		if (shape == 1) {
			vec2 p = pix / b;
			vec2 r = vec2(1.0, 1.7320508);
			vec2 h = r * 0.5;
			vec2 ga = mod(p, r) - h;
			vec2 gb = mod(p - h, r) - h;
			vec2 gg = dot(ga, ga) < dot(gb, gb) ? ga : gb;
			cuv = ((p - gg) * b + 0.5 * dims) / dims;
		} else {
			vec2 cell = floor(pix / b);
			cuv = ((cell + 0.5) * b + 0.5 * dims) / dims;
		}
		float lv = clamp(log2(b / 3.0), 0.0, 5.0);
		int lo = int(floor(lv));
		float fr = lv - float(lo);
		vec2 tap = vec2(b / 3.0) / dims;
		vec4 sum = vec4(0.0);
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 q = cuv + vec2(float(i), float(j)) * tap;
				sum += mix(level(lo, q, TEXTURE), level(min(lo + 1, 5), q, TEXTURE), fr);
			}
		}
		COLOR = sum / 9.0;
	}
}
