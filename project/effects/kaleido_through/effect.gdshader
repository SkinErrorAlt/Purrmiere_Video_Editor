shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.1, 3.0) = 0.6;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform int segments : hint_range(3, 16) = 6;
uniform float spin : hint_range(-2.0, 2.0) = 0.5;
uniform float zoom : hint_range(0.0, 3.0) = 1.0;
uniform float softness : hint_range(0.0, 1.0) = 0.3;
uniform int edges : hint_range(0, 1) = 0;

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

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_in = false;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		vec2 asp = vec2(sz.x / sz.y, 1.0);
		vec2 ctr = clamp(centre, vec2(0.0), vec2(1.0));
		float e = g * g * (3.0 - 2.0 * g);
		float sgn = is_in ? -1.0 : 1.0;
		vec2 rel = (UV - ctr) * asp;
		float r = length(rel);
		float far_d = 0.0;
		far_d = max(far_d, length(ctr * asp));
		far_d = max(far_d, length((ctr - vec2(1.0, 0.0)) * asp));
		far_d = max(far_d, length((ctr - vec2(0.0, 1.0)) * asp));
		far_d = max(far_d, length((ctr - vec2(1.0, 1.0)) * asp));
		float soft = 0.02 + clamp(softness, 0.0, 1.0) * 0.5;
		float reach = e * (far_d + soft + 0.02);
		float m = 1.0 - smoothstep(reach - soft, reach, r);
		float turn = sgn * clamp(spin, -2.0, 2.0) * 6.2831853 * e * e;
		float seg = 6.2831853 / float(clamp(segments, 3, 16));
		float a = atan(rel.y, rel.x) - turn;
		float am = mod(a, seg);
		am = am > seg * 0.5 ? seg - am : am;
		float rr = r * exp(-sgn * clamp(zoom, 0.0, 3.0) * 0.6 * e * e);
		float as = am + turn;
		vec2 src = ctr + vec2(cos(as), sin(as)) * rr / asp;
		vec4 k = texture(TEXTURE, wrap(src));
		COLOR = mix(c, k, m);
	}
}
