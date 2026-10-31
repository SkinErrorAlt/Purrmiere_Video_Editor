shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.05, 3.0) = 0.5;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float turns : hint_range(-3.0, 3.0) = 1.0;
uniform float size : hint_range(0.1, 2.0) = 0.7;
uniform float zoom : hint_range(0.0, 3.0) = 1.0;
uniform float blur : hint_range(0.0, 1.0) = 0.7;
uniform int edges : hint_range(0, 1) = 0;

const int TAPS = 24;

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
	vec4 c = texture(TEXTURE, UV);
	bool is_in = false;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		vec2 asp = vec2(sz.x / sz.y, 1.0);
		vec2 ctr = clamp(centre, vec2(-0.5), vec2(1.5));
		float d = when == 3 ? 0.4 : max(duration, 0.01);
		float f = g * g;
		float sgn = is_in ? -1.0 : 1.0;
		float lz = sgn * clamp(zoom, 0.0, 3.0) * 0.7 * f;
		vec2 rel = (UV - ctr) * asp * exp(-lz);
		float r = length(rel);
		float fall = exp(-pow(r / clamp(size, 0.1, 2.0), 2.0));
		float amax = clamp(turns, -3.0, 3.0) * 6.2831853;
		float a = sgn * amax * f * fall;
		float omega = abs(amax) * fall * 2.0 * g / d;
		float arc = omega * clamp(blur, 0.0, 1.0) * 0.045;
		float arc_px = arc * r * sz.y;
		vec2 base = rot(rel, -a);
		if (arc_px < 0.5) {
			COLOR = texture(TEXTURE, wrap(ctr + base / asp));
		} else {
			float jit = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
			int n = int(clamp(ceil(arc_px / 2.0), 3.0, float(TAPS)));
			vec4 sum = vec4(0.0);
			for (int i = 0; i < TAPS; i++) {
				if (i >= n) {
					break;
				}
				float o = (float(i) + jit) / float(n) - 0.5;
				sum += texture(TEXTURE, wrap(ctr + rot(base, o * arc) / asp));
			}
			COLOR = sum / float(n);
		}
	}
}
