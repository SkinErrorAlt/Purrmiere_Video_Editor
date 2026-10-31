shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.05, 2.0) = 0.3;
uniform int direction : hint_range(0, 5) = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float distance : hint_range(0.25, 4.0) = 1.5;
uniform float blur : hint_range(0.0, 1.0) = 0.8;
uniform int edges : hint_range(0, 1) = 0;
uniform int stage = 0;

const int MAX_COMB = 16;

float travel(float t) {
	float d = max(duration, 0.01);
	float dist = clamp(distance, 0.25, 4.0);
	if (when == 3) {
		return -dist * clamp(progress, 0.0, 1.0);
	}
	float v = 0.0;
	if (when == 0 || when == 2) {
		float u = (clip_duration - t) / d;
		if (u < 1.0) {
			float p = clamp(1.0 - u, 0.0, 1.0);
			v -= dist * p * p;
		}
	}
	if (when == 0 || when == 1) {
		float u = t / d;
		if (u < 1.0) {
			float q = clamp(1.0 - u, 0.0, 1.0);
			v += dist * q * q;
		}
	}
	return v;
}

vec2 axis() {
	if (direction == 1) {
		return vec2(1.0, 0.0);
	}
	if (direction == 2) {
		return vec2(0.0, -1.0);
	}
	if (direction == 3) {
		return vec2(0.0, 1.0);
	}
	return vec2(-1.0, 0.0);
}

bool spinning() {
	return direction >= 4;
}

float spin_sign() {
	return direction == 4 ? 1.0 : -1.0;
}

vec2 wrap(vec2 uv) {
	if (edges == 1) {
		return fract(uv);
	}
	vec2 m = mod(uv, 2.0);
	return clamp(mix(m, 2.0 - m, step(vec2(1.0), m)), vec2(0.0), vec2(1.0));
}

vec2 rotate_about_centre(vec2 uv, float ang, vec2 asp) {
	vec2 q = (uv - 0.5) * asp;
	float cs = cos(ang);
	float sn = sin(ang);
	q = vec2(cs * q.x - sn * q.y, sn * q.x + cs * q.y);
	return q / asp + 0.5;
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	vec2 asp = vec2(size.x / size.y, 1.0);
	float h = 1.0 / 240.0;
	float pos = travel(clip_time);
	float vel = (travel(clip_time + h) - travel(clip_time - h)) / (2.0 * h);
	if (when == 3) {
		vel = clamp(distance, 0.25, 4.0) * 24.0 * clamp(progress, 0.0, 1.0) * (1.0 - clamp(progress, 0.0, 1.0));
	}
	float shutter = clamp(blur, 0.0, 1.0) / 30.0;
	float streak = abs(vel) * shutter;
	float jit = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	if (spinning()) {
		float ang = pos * TAU * 0.5 * spin_sign();
		float arc = streak * TAU * 0.5;
		float arc_px = arc * length(size) * 0.5;
		float k = clamp(ceil(arc_px / 48.0), 1.0, float(MAX_COMB));
		float seg = arc / k;
		vec4 sum = vec4(0.0);
		if (stage == 0) {
			float radius_px = length((UV - 0.5) * size) * seg * 0.5;
			if (arc_px < 0.5 || radius_px < 0.5) {
				COLOR = texture(TEXTURE, UV);
			} else {
				float turn0 = jit * TAU;
				for (int i = 0; i < 16; i++) {
					float rr = sqrt((float(i) + 0.5) / 16.0) * radius_px;
					float aa = float(i) * 2.39996323 + turn0;
					sum += texture(TEXTURE, wrap(UV + vec2(cos(aa), sin(aa)) * rr / size));
				}
				COLOR = sum / 16.0;
			}
		} else {
			int kk = int(k);
			for (int i = 0; i < MAX_COMB; i++) {
				if (i >= kk) {
					break;
				}
				float off = (float(i) - (k - 1.0) * 0.5) * seg;
				sum += texture(TEXTURE, wrap(rotate_about_centre(UV, ang + off, asp)));
			}
			COLOR = sum / max(float(kk), 1.0);
		}
	} else {
		vec2 ax = axis();
		vec2 span = abs(ax.x) > 0.5 ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
		float len_px = streak * dot(span, size);
		float k = clamp(ceil(len_px / 48.0), 1.0, float(MAX_COMB));
		vec2 seg = ax * streak / k;
		vec4 sum = vec4(0.0);
		if (stage == 0) {
			if (len_px < 0.5) {
				COLOR = texture(TEXTURE, UV);
			} else {
				int n = int(clamp(ceil(len_px / k), 2.0, 48.0));
				for (int i = 0; i < 48; i++) {
					if (i >= n) {
						break;
					}
					float f = (float(i) + jit) / float(n) - 0.5;
					sum += texture(TEXTURE, wrap(UV + seg * f));
				}
				COLOR = sum / float(n);
			}
		} else {
			vec2 base = UV + ax * pos;
			int kk = int(k);
			for (int i = 0; i < MAX_COMB; i++) {
				if (i >= kk) {
					break;
				}
				float off = float(i) - (k - 1.0) * 0.5;
				sum += texture(TEXTURE, wrap(base + seg * off));
			}
			COLOR = sum / max(float(kk), 1.0);
		}
	}
}
