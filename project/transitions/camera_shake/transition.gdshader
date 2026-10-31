shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int style = 0;
uniform float strength : hint_range(0.0, 0.25) = 0.05;
uniform float rotation : hint_range(0.0, 15.0) = 3.0;
uniform float speed : hint_range(2.0, 40.0) = 14.0;
uniform float zoom : hint_range(0.0, 0.5) = 0.08;
uniform float blur : hint_range(0.0, 1.0) = 0.5;
uniform float channel_split : hint_range(0.0, 1.0) = 0.5;
uniform float blend : hint_range(0.02, 0.5) = 0.12;

const int SAMPLES = 8;
const float SPLIT_GAIN = 0.007;
const float STEP = 0.004;

float envelope(float t) {
	float s = sin(TR_PI * clamp(t, 0.0, 1.0));
	return s * s;
}

float rate() {
	return style == 1 ? speed * 0.4 : speed;
}

vec3 shake_at(float t) {
	float env = envelope(t);
	float n = t * rate();
	vec2 o = vec2(tr_noise(vec2(n, 1.7)), tr_noise(vec2(n + 31.0, 8.3))) - 0.5;
	float r = tr_noise(vec2(n + 57.0, 4.1)) - 0.5;
	if (style == 1) {
		float m = t * speed;
		vec2 rumble = vec2(tr_noise(vec2(m + 71.0, 2.9)), tr_noise(vec2(m + 93.0, 6.2))) - 0.5;
		o = (o * 0.85 + rumble * 0.15) * vec2(0.4, 1.5) * 2.6;
		r *= 0.6;
	}
	return vec3(o * 2.0 * strength * env, radians(r * 2.0 * rotation * env));
}

vec2 place(vec2 uv, float t) {
	vec3 s = shake_at(t);
	float k = 1.0 + (style == 1 ? zoom * 1.5 + strength * 2.3 : zoom) * envelope(t);
	return tr_frame_uv(tr_rotate(tr_world(uv) - s.xy, -s.z) / k);
}

vec4 split_fetch(vec2 suv, vec2 off, bool use_from) {
	if (off.x == 0.0 && off.y == 0.0) {
		return use_from ? from_mirrored(suv) : to_mirrored(suv);
	}
	vec4 r = use_from ? from_mirrored(suv + off) : to_mirrored(suv + off);
	vec4 g = use_from ? from_mirrored(suv) : to_mirrored(suv);
	vec4 b = use_from ? from_mirrored(suv - off) : to_mirrored(suv - off);
	return vec4(r.r, g.g, b.b, max(g.a, max(r.a, b.a)));
}

vec4 shaken(vec2 uv, float t, float mixer, vec2 off) {
	vec2 suv = place(uv, t);
	if (mixer <= 0.0) {
		return split_fetch(suv, off, true);
	}
	if (mixer >= 1.0) {
		return split_fetch(suv, off, false);
	}
	return mix(split_fetch(suv, off, true), split_fetch(suv, off, false), mixer);
}

float dither(vec2 uv) {
	vec2 px = floor(uv * frame_px);
	return fract(52.9829189 * fract(dot(px, vec2(0.06711056, 0.00583715))));
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float b = max(blend, 0.005);
	float mixer = smoothstep(0.5 - b, 0.5 + b, p);
	vec2 off = vec2(0.0);
	if (channel_split > 0.0) {
		vec2 vel = (place(uv, p + STEP) - place(uv, p - STEP)) / (2.0 * STEP);
		off = vel * SPLIT_GAIN * channel_split * smoothstep(0.0, 0.02, p) * smoothstep(0.0, 0.02, 1.0 - p);
		float len = length(off);
		if (len > 0.03) {
			off *= 0.03 / len;
		}
	}
	float shutter = blur * 0.8 / max(rate(), 0.5) * sin(TR_PI * p);
	if (shutter < 0.00001) {
		return shaken(uv, p, mixer, off);
	}
	float j = dither(uv);
	vec4 acc = vec4(0.0);
	for (int i = 0; i < SAMPLES; i++) {
		float f = (float(i) + j) / float(SAMPLES) - 0.5;
		acc += shaken(uv, p + f * shutter, mixer, off);
	}
	return acc / float(SAMPLES);
}

void fragment() {
	COLOR = transition(UV);
}
