shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.05, 3.0) = 0.6;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int direction : hint_range(0, 3) = 0;
uniform float perspective : hint_range(0.0, 1.0) = 0.5;
uniform float shade : hint_range(0.0, 1.0) = 0.5;
uniform float shrink : hint_range(0.0, 0.8) = 0.2;

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

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_in = false;
	float g = trans_amount(is_in);
	vec2 sz = max(tex_size, vec2(1.0));
	float asp = sz.x / sz.y;
	bool vertical = direction >= 2;
	vec2 s = (UV - 0.5) * 2.0 * vec2(asp, 1.0);
	float ex = asp;
	float ey = 1.0;
	if (vertical) {
		s = s.yx;
		ex = 1.0;
		ey = asp;
	}
	float e = g * g * (3.0 - 2.0 * g);
	float dir_sign = (direction == 0 || direction == 2) ? 1.0 : -1.0;
	float th = e * 1.5707963 * (is_in ? -1.0 : 1.0) * dir_sign;
	float k = 1.0 - clamp(shrink, 0.0, 0.8) * sin(e * 3.1415926);
	s /= max(k, 0.05);
	float a = ex;
	float dd = mix(12.0, 2.2, clamp(perspective, 0.0, 1.0)) * max(ex, ey);
	float ct = cos(th);
	float sn = sin(th);
	float den = dd * ct + s.x * sn;
	float u = (s.x * (dd + a * (1.0 - ct)) + dd * a * sn) / max(den, 0.00001);
	float zz = a - u * sn - a * ct;
	float v = s.y * (dd + zz) / dd;
	float mu = clamp((a - abs(u)) / max(fwidth(u), 0.00001) + 0.5, 0.0, 1.0);
	float mv = clamp((ey - abs(v)) / max(fwidth(v), 0.00001) + 0.5, 0.0, 1.0);
	if (g <= 0.0001) {
		COLOR = c;
	} else if (den <= 0.00001 || ct < 0.0005) {
		COLOR = vec4(0.0);
	} else {
		vec2 face = vertical ? vec2(v / asp, u) : vec2(u / asp, v);
		vec4 pic = texture(TEXTURE, clamp(face * 0.5 + 0.5, vec2(0.0), vec2(1.0)));
		float lit = 1.0 - clamp(shade, 0.0, 1.0) * (1.0 - ct) * 0.85;
		COLOR = vec4(pic.rgb * lit, pic.a) * mu * mv;
	}
}
