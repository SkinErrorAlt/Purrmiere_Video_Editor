shader_type canvas_item;
render_mode blend_disabled;

uniform float time = 0.0;
uniform float seq_fps = 30.0;
uniform int light = 1;
uniform int mains = 0;
uniform float shutter : hint_range(25.0, 4000.0) = 400.0;
uniform float readout : hint_range(2.0, 40.0) = 24.0;
uniform float depth : hint_range(0.0, 1.0) = 0.75;
uniform float pwm : hint_range(200.0, 4000.0) = 1000.0;
uniform float duty : hint_range(0.05, 0.95) = 0.35;
uniform int seed = 0;

vec3 to_lin(vec3 v) {
	vec3 lo = v / 12.92;
	vec3 hi = pow((v + 0.055) / 1.055, vec3(2.4));
	return mix(hi, lo, step(v, vec3(0.04045)));
}

vec3 to_srgb(vec3 v) {
	vec3 lo = v * 12.92;
	vec3 hi = 1.055 * pow(max(v, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055;
	return mix(hi, lo, step(v, vec3(0.0031308)));
}

float sinc(float x) {
	return abs(x) < 0.0001 ? 1.0 : sin(x) / x;
}

float coef(int k) {
	if (light == 1) {
		return k == 1 ? -0.72 : (k == 2 ? -0.18 : (k == 3 ? -0.08 : (k == 4 ? -0.04 : 0.0)));
	}
	if (light == 2) {
		float d = clamp(duty, 0.05, 0.95);
		return 2.0 * sinc(PI * float(k) * d);
	}
	if (light == 3) {
		return k == 1 ? -0.11 : (k == 2 ? -0.015 : 0.0);
	}
	return k == 1 ? -0.34 : (k == 2 ? -0.07 : (k == 3 ? -0.02 : 0.0));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 lin = to_lin(clamp(rgb, 0.0, 1.0));
	float fps = max(seq_fps, 1.0);
	float frame_n = floor(time * fps + 0.5);
	float f = light == 2 ? pwm : (mains == 1 ? 120.0 : 100.0);
	float e = 1.0 / max(shutter, 1.0);
	float phase0 = fract(sin(float(seed) * 12.9898 + 4.1414) * 43758.5453);
	float cyc = fract(frame_n * (f / fps)) + phase0 + (UV.y * readout * 0.001 + e * 0.5) * f;
	vec3 chan = vec3(1.0);
	vec3 lag = vec3(0.0);
	if (light == 0) {
		chan = vec3(0.72, 0.92, 1.38);
		lag = vec3(0.07, 0.045, 0.0);
	} else if (light == 3) {
		chan = vec3(0.8, 1.0, 1.3);
		lag = vec3(0.02, 0.01, 0.0);
	}
	vec3 g = vec3(1.0);
	for (int k = 1; k <= 6; k++) {
		float ak = coef(k);
		if (ak == 0.0) {
			continue;
		}
		float kf = float(k) * f;
		float s = sinc(PI * kf * e);
		float ph = TAU * float(k) * fract(cyc);
		g += depth * ak * s * chan * cos(vec3(ph) - TAU * float(k) * lag);
	}
	g = max(g, vec3(0.0));
	float hot = smoothstep(0.9, 1.0, max(rgb.r, max(rgb.g, rgb.b)));
	vec3 headroom = lin * (1.0 + 5.0 * hot);
	vec3 dim = min(headroom * g, lin);
	vec3 outl = mix(lin * g, dim, step(g, vec3(1.0)));
	vec3 outc = clamp(to_srgb(outl), 0.0, 1.0);
	COLOR = vec4(outc * a, a);
}
