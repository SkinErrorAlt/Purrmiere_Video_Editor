shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.05, 3.0) = 0.5;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int slices : hint_range(2, 24) = 6;
uniform float angle : hint_range(-180.0, 180.0) = 90.0;
uniform float stagger : hint_range(0.0, 1.0) = 0.35;
uniform float blur : hint_range(0.0, 1.0) = 0.6;

const int TAPS = 12;

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

vec4 fetch(sampler2D tex, vec2 pix, vec2 sz) {
	vec2 inside = step(vec2(0.0), pix) * step(pix, sz);
	return texture(tex, clamp(pix / sz, vec2(0.0), vec2(1.0))) * inside.x * inside.y;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_in = true;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float rad = radians(angle);
		vec2 dir = vec2(sin(rad), -cos(rad));
		vec2 nrm = vec2(-dir.y, dir.x);
		vec2 pix = UV * sz;
		vec2 pc = pix - 0.5 * sz;
		float ext_d = abs(dir.x) * sz.x + abs(dir.y) * sz.y;
		float ext_n = abs(nrm.x) * sz.x + abs(nrm.y) * sz.y;
		float y = dot(pc, nrm) / ext_n + 0.5;
		float n = float(clamp(slices, 2, 24));
		float idx = clamp(floor(y * n), 0.0, n - 1.0);
		float sgn = mod(idx, 2.0) < 0.5 ? 1.0 : -1.0;
		float rank = idx / max(n - 1.0, 1.0);
		float st = clamp(stagger, 0.0, 1.0);
		float gl = clamp(g * (1.0 + st) - st * rank, 0.0, 1.0);
		float e = gl * gl * (1.6 - 0.6 * gl);
		float dist = e * ext_d * 1.08 / (1.0 - 0.18 * clamp(blur, 0.0, 1.0));
		float off = is_in ? -sgn * dist : sgn * dist;
		vec2 src = pix - dir * off;
		float bl = clamp(blur, 0.0, 1.0) * 0.35 * dist;
		vec4 acc = vec4(0.0);
		for (int j = 0; j < TAPS; j++) {
			float k = float(j) / float(TAPS - 1) - 0.5;
			acc += fetch(TEXTURE, src + dir * sign(off) * bl * k, sz);
		}
		COLOR = acc / float(TAPS);
	}
}
