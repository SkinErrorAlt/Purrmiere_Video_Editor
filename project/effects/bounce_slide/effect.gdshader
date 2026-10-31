shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.1, 3.0) = 0.5;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float angle : hint_range(-180.0, 180.0) = 90.0;
uniform int leaves : hint_range(0, 1) = 0;
uniform float bounce : hint_range(0.0, 1.0) = 0.5;
uniform float blur : hint_range(0.0, 1.0) = 0.6;
uniform float squash : hint_range(0.0, 1.0) = 0.3;

const int TAPS = 16;

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

float pos_at(float g, bool is_in) {
	g = clamp(g, 0.0, 1.0);
	float b = clamp(bounce, 0.0, 1.0);
	if (is_in) {
		float s = 2.6 * b;
		float u = 1.0 - g;
		float eo = 1.0 + (s + 1.0) * pow(u - 1.0, 3.0) + s * pow(u - 1.0, 2.0);
		return -1.35 * (1.0 - eo);
	}
	float ei = g * g - b * 0.06 * sin(3.1415926 * g);
	return (leaves == 0 ? 1.35 : -1.35) * ei;
}

vec4 fetch(sampler2D tex, vec2 uv) {
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	return texture(tex, clamp(uv, vec2(0.0), vec2(1.0))) * inside.x * inside.y;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_in = false;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float rad = radians(angle);
		vec2 dir = vec2(sin(rad), -cos(rad));
		vec2 nrm = vec2(-dir.y, dir.x);
		float ext = abs(dir.x) * sz.x + abs(dir.y) * sz.y;
		float d = when == 3 ? 0.5 : max(duration, 0.01);
		float pos = pos_at(g, is_in);
		float hg = 0.004;
		float vel = (pos_at(g + hg, is_in) - pos_at(g - hg, is_in)) / (2.0 * hg) / d;
		float speed = abs(vel);
		float st = 1.0 + clamp(squash, 0.0, 1.0) * 0.45 * clamp(speed * 0.15, 0.0, 1.0);
		vec2 p = UV * sz - 0.5 * sz - dir * pos * ext;
		float along = dot(p, dir) / st;
		float across = dot(p, nrm) * sqrt(st);
		vec2 q = dir * along + nrm * across;
		float streak = min(speed * clamp(blur, 0.0, 1.0) * 0.035, 0.16) * ext;
		if (streak < 0.75) {
			COLOR = fetch(TEXTURE, (q + 0.5 * sz) / sz);
		} else {
			float jit = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
			vec4 sum = vec4(0.0);
			for (int i = 0; i < TAPS; i++) {
				float o = (float(i) + jit) / float(TAPS) - 0.5;
				sum += fetch(TEXTURE, (q + dir * o * streak + 0.5 * sz) / sz);
			}
			COLOR = sum / float(TAPS);
		}
	}
}
