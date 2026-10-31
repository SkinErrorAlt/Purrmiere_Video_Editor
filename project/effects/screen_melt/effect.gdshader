shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.1, 3.0) = 1.0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int style : hint_range(0, 1) = 0;
uniform float width : hint_range(1.0, 64.0) = 8.0;
uniform float stagger : hint_range(0.0, 0.9) = 0.45;
uniform int direction : hint_range(0, 1) = 0;
uniform int seed : hint_range(0, 9999) = 0;

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

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash11(i), hash11(i + 1.0), u);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_in = false;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float ps = max(px_scale, 0.0001);
		float sd = float(seed) * 13.1 + 7.0;
		float st = clamp(stagger, 0.0, 0.9);
		float y = direction == 1 ? 1.0 - UV.y : UV.y;
		float delay = 0.0;
		if (style == 0) {
			float col = floor(UV.x * sz.x / max(width * ps, 0.5));
			float walk = noise1(col * 0.09 + sd) * 0.7 + noise1(col * 0.37 + sd * 2.0) * 0.3;
			delay = st * clamp(walk * 0.8 + hash11(col + sd * 3.0) * 0.2, 0.0, 1.0);
		} else {
			float xs = UV.x * sz.x / max(width * ps * 6.0, 1.0);
			float wav = noise1(xs * 0.35 + sd) * 0.6 + noise1(xs * 1.3 + sd * 1.9) * 0.3 + noise1(xs * 4.1 + sd * 0.7) * 0.1;
			delay = st * clamp(wav, 0.0, 1.0);
		}
		if (is_in) {
			delay = st - delay;
		}
		float l = clamp((g - delay) / max(1.0 - st, 0.0001), 0.0, 1.0);
		float off = l * l * 1.03;
		float ys = is_in ? y + off : y - off;
		vec2 src = vec2(UV.x, direction == 1 ? 1.0 - ys : ys);
		float inside = step(0.0, ys) * step(ys, 1.0);
		vec4 p = texture(TEXTURE, clamp(src, vec2(0.0), vec2(1.0))) * inside;
		if (style == 1 && inside > 0.0) {
			float lead = is_in ? 1.0 - ys : ys;
			float soft = clamp(lead * sz.y / (3.0 * ps), 0.0, 1.0);
			p *= mix(1.0, soft, step(0.0001, l));
		}
		COLOR = p;
	}
}
