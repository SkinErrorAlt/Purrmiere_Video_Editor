shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float at : hint_range(0.0, 600.0) = 0.0;
uniform float zoom : hint_range(-50.0, 300.0) = 30.0;
uniform float punch_time : hint_range(0.01, 2.0) = 0.12;
uniform float hold : hint_range(0.0, 600.0) = 2.0;
uniform float release : hint_range(0.0, 3.0) = 0.25;
uniform float repeat : hint_range(0.0, 60.0) = 0.0;
uniform float bounce : hint_range(0.0, 1.0) = 0.35;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float turn : hint_range(-45.0, 45.0) = 0.0;
uniform float blur : hint_range(0.0, 1.0) = 0.6;
uniform float jolt : hint_range(0.0, 1.0) = 0.0;
uniform int edges : hint_range(0, 2) = 0;

float since_punch(float t) {
	float local = t - at;
	if (local < 0.0) {
		return -1.0;
	}
	if (repeat > 0.001) {
		local = mod(local, repeat);
	}
	return local;
}

float envelope(float t) {
	float local = since_punch(t);
	if (local < 0.0) {
		return 0.0;
	}
	float pt = max(punch_time, 0.001);
	if (local < pt) {
		float x = local / pt;
		float c1 = clamp(bounce, 0.0, 1.0) * 2.5;
		float c3 = c1 + 1.0;
		float xm = x - 1.0;
		return 1.0 + c3 * xm * xm * xm + c1 * xm * xm;
	}
	local -= pt;
	if (local < max(hold, 0.0)) {
		return 1.0;
	}
	local -= max(hold, 0.0);
	if (release <= 0.001 || local >= release) {
		return 0.0;
	}
	float x = local / release;
	return 1.0 - x * x * (3.0 - 2.0 * x);
}

vec2 jolt_offset(float t) {
	float local = since_punch(t);
	if (local < 0.0 || jolt <= 0.0) {
		return vec2(0.0);
	}
	float env = exp(-local * 9.0) * clamp(local * 60.0, 0.0, 1.0);
	return vec2(sin(local * 71.0), cos(local * 53.0 + 1.3)) * 0.025 * clamp(jolt, 0.0, 1.0) * env;
}

vec2 source_uv(vec2 uv, float e, vec2 j, vec2 asp) {
	float s = max(1.0 + zoom * 0.01 * e, 0.05);
	vec2 q = (uv - centre) * asp;
	float ang = -radians(turn) * e;
	float cs = cos(ang);
	float sn = sin(ang);
	q = vec2(cs * q.x - sn * q.y, sn * q.x + cs * q.y) / s;
	q -= j;
	return q / asp + centre;
}

vec4 fetch(sampler2D tex, vec2 uv) {
	if (edges == 2) {
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			return vec4(0.0);
		}
		return texture(tex, uv);
	}
	if (edges == 1) {
		return texture(tex, fract(uv));
	}
	vec2 m = mod(uv, 2.0);
	return texture(tex, clamp(mix(m, 2.0 - m, step(vec2(1.0), m)), vec2(0.0), vec2(1.0)));
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	vec2 asp = vec2(size.x / size.y, 1.0);
	float shutter = clamp(blur, 0.0, 1.0) / 60.0;
	float e0 = envelope(clip_time - shutter);
	float e1 = envelope(clip_time + shutter);
	vec2 j0 = jolt_offset(clip_time - shutter);
	vec2 j1 = jolt_offset(clip_time + shutter);
	vec2 a0 = source_uv(UV, e0, j0, asp);
	vec2 a1 = source_uv(UV, e1, j1, asp);
	float travel = length((a1 - a0) * size) / max(px_scale, 0.0001);
	int n = shutter > 0.0 ? int(clamp(ceil(travel / 1.5), 1.0, 24.0)) : 1;
	vec4 sum = vec4(0.0);
	if (n <= 1) {
		sum = fetch(TEXTURE, source_uv(UV, envelope(clip_time), jolt_offset(clip_time), asp));
	} else {
		float jit = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		for (int i = 0; i < 24; i++) {
			if (i >= n) {
				break;
			}
			float f = (float(i) + jit) / float(n);
			float tt = clip_time + mix(-shutter, shutter, f);
			sum += fetch(TEXTURE, source_uv(UV, envelope(tt), jolt_offset(tt), asp));
		}
		sum /= float(n);
	}
	COLOR = sum;
}
