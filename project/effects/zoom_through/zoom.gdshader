shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.05, 3.0) = 0.4;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int style : hint_range(0, 1) = 0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float strength : hint_range(0.2, 8.0) = 3.0;
uniform float turn : hint_range(-360.0, 360.0) = 0.0;
uniform float blur : hint_range(0.0, 1.0) = 0.8;
uniform int edges : hint_range(0, 1) = 0;
uniform int stage = 0;

const int MAX_COMB = 16;

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

vec2 rot(vec2 p, float a) {
	float cs = cos(a);
	float sn = sin(a);
	return vec2(cs * p.x - sn * p.y, sn * p.x + cs * p.y);
}

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	vec2 asp = vec2(sz.x / sz.y, 1.0);
	bool is_in = false;
	float g = trans_amount(is_in);
	float d = when == 3 ? 0.4 : max(duration, 0.01);
	float k_zoom = log(1.0 + clamp(strength, 0.2, 8.0));
	float turn_rad = radians(clamp(turn, -360.0, 360.0));
	float f = g * g;
	float dir = style == 0 ? 1.0 : -1.0;
	float sgn = is_in ? -1.0 : 1.0;
	float lz = dir * sgn * k_zoom * f;
	float ang = sgn * turn_rad * f;
	float shutter = clamp(blur, 0.0, 1.0) * 0.07;
	float streak_l = k_zoom * 2.0 * g / d * shutter;
	float streak_a = abs(turn_rad) * 2.0 * g / d * shutter;
	float streak = sqrt(streak_l * streak_l + streak_a * streak_a);
	float jit = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	vec2 c = clamp(centre, vec2(-0.5), vec2(1.5));
	if (g <= 0.0001) {
		COLOR = texture(TEXTURE, UV);
	} else if (stage == 0) {
		vec2 rel = (UV - c) * asp;
		float len_px = length(rel) * sz.y * streak;
		if (len_px < 0.5) {
			COLOR = texture(TEXTURE, UV);
		} else {
			float k = clamp(ceil(len_px / 48.0), 1.0, float(MAX_COMB));
			float seg_l = streak_l / k;
			float seg_a = streak_a / k;
			int n = int(clamp(ceil(len_px / k), 2.0, 48.0));
			vec4 sum = vec4(0.0);
			for (int i = 0; i < 48; i++) {
				if (i >= n) {
					break;
				}
				float o = (float(i) + jit) / float(n) - 0.5;
				vec2 q = rot(rel * exp(o * seg_l), o * seg_a);
				sum += texture(TEXTURE, wrap(c + q / asp));
			}
			COLOR = sum / float(n);
		}
	} else {
		vec2 rel = rot((UV - c) * asp, -ang) * exp(-lz);
		float len_px = length(rel) * sz.y * streak;
		float k = clamp(ceil(len_px / 48.0), 1.0, float(MAX_COMB));
		float seg_l = streak_l / k;
		float seg_a = streak_a / k;
		int kk = int(k);
		vec4 sum = vec4(0.0);
		for (int i = 0; i < MAX_COMB; i++) {
			if (i >= kk) {
				break;
			}
			float o = float(i) - (k - 1.0) * 0.5;
			vec2 q = rot(rel * exp(o * seg_l), o * seg_a);
			sum += texture(TEXTURE, wrap(c + q / asp));
		}
		COLOR = sum / max(float(kk), 1.0);
	}
}
