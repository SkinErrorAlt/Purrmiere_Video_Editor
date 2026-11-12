shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform int pass_mode = 0;
uniform sampler2D half_tex : filter_linear, repeat_disable;
uniform sampler2D quarter_tex : filter_linear, repeat_disable;
uniform float depth : hint_range(0.0, 60.0) = 18.0;
uniform int timing = 0;
uniform float start : hint_range(0.0, 60.0) = 0.2;
uniform float hunt_length : hint_range(0.2, 10.0) = 1.8;
uniform float interval : hint_range(0.5, 30.0) = 4.0;
uniform float offset : hint_range(-1.0, 1.0) = 0.0;
uniform float breathing : hint_range(0.0, 6.0) = 1.5;
uniform float fringe : hint_range(0.0, 1.0) = 0.5;
uniform float highlight : hint_range(0.0, 3.0) = 1.2;
uniform int seed = 0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float h1(float n) {
	return fract(sin(n * 12.9898 + 78.233) * 43758.5453);
}

float ease(float x) {
	return x * x * (3.0 - 2.0 * x);
}

float hunt(float tau, float hs) {
	float k0 = 0.0;
	float k1 = 0.55 * (0.8 + 0.4 * h1(hs + 1.0));
	float k2 = -1.0;
	float k3 = 0.45 * (0.75 + 0.5 * h1(hs + 2.0));
	float k4 = -0.17 * (0.6 + 0.8 * h1(hs + 3.0));
	float t1 = 0.15;
	float t2 = 0.42;
	float t3 = 0.65;
	float t4 = 0.82;
	float v = 0.0;
	if (tau <= 0.0 || tau >= 1.0) {
		v = 0.0;
	} else if (tau < t1) {
		v = mix(k0, k1, ease(tau / t1));
	} else if (tau < t2) {
		v = mix(k1, k2, ease((tau - t1) / (t2 - t1)));
	} else if (tau < t3) {
		v = mix(k2, k3, ease((tau - t2) / (t3 - t2)));
	} else if (tau < t4) {
		v = mix(k3, k4, ease((tau - t3) / (t4 - t3)));
	} else {
		v = mix(k4, 0.0, ease((tau - t4) / (1.0 - t4)));
	}
	return h1(hs) < 0.5 ? v : -v;
}

float focus_now() {
	if (timing == 2) {
		return clamp(offset, -1.0, 1.0);
	}
	float t = clip_time - start;
	if (t < 0.0) {
		return 0.0;
	}
	float n = 0.0;
	if (timing == 1) {
		float per = max(interval, hunt_length);
		n = floor(t / per);
		t -= n * per;
	}
	return hunt(t / max(hunt_length, 0.01), float(seed) * 3.17 + n * 7.31);
}

vec2 mirror_uv(vec2 uv) {
	vec2 m = abs(uv);
	return 1.0 - abs(1.0 - m);
}

float shape_w(float q, float side) {
	return side > 0.0 ? 0.45 + 1.1 * q * q : 1.5 - 1.15 * q * q;
}

vec4 lens_blur(sampler2D tex, vec2 px, vec2 uv, float r_px, float f, int n) {
	float side = sign(f);
	float rb_scale = 1.0 + 0.15 * clamp(fringe, 0.0, 1.0) * side;
	float rmax = r_px * max(rb_scale, 1.0);
	vec4 sum_g = vec4(0.0);
	float w_g = 0.0;
	vec4 sum_rb = vec4(0.0);
	float w_rb = 0.0;
	for (int i = 0; i < 160; i++) {
		if (i >= n) {
			break;
		}
		float q = sqrt((float(i) + 0.5) / float(n));
		float th = float(i) * 2.39996323;
		float rr = q * rmax;
		vec4 s = texture(tex, mirror_uv(uv + vec2(cos(th), sin(th)) * rr * px));
		float l = dot(s.rgb, LUMA);
		float boost = 1.0 + pow(clamp(l, 0.0, 1.0), 4.0) * highlight * 8.0;
		float qg = rr / max(r_px, 0.0001);
		if (qg <= 1.0) {
			float w = boost * shape_w(qg, side);
			sum_g += s * w;
			w_g += w;
		}
		float qrb = rr / max(r_px * rb_scale, 0.0001);
		if (qrb <= 1.0) {
			float w = boost * shape_w(qrb, side);
			sum_rb += s * w;
			w_rb += w;
		}
	}
	vec4 g = sum_g / max(w_g, 0.0001);
	vec4 rb = sum_rb / max(w_rb, 0.0001);
	return vec4(rb.r, g.g, rb.b, g.a);
}

void fragment() {
	float f = focus_now();
	float s = 1.0 + breathing * 0.01 * f;
	vec2 uv = 0.5 + (UV - 0.5) / s;
	if (pass_mode == 0) {
		float r_q = depth * abs(f) * px_scale;
		float r_h = r_q * 2.0;
		if (r_h < 0.5) {
			COLOR = texture(half_tex, mirror_uv(uv));
		} else if (r_h <= 7.0) {
			int n = int(clamp(3.3 * r_h * r_h, 24.0, 160.0));
			COLOR = lens_blur(half_tex, 1.0 / (tex_size * 2.0), uv, r_h, f, n);
		} else {
			int n = int(clamp(3.3 * r_q * r_q, 24.0, 160.0));
			COLOR = lens_blur(quarter_tex, 1.0 / tex_size, uv, r_q, f, n);
		}
	} else {
		float r_full = depth * abs(f) * px_scale * 2.0;
		float b = smoothstep(2.5, 4.5, r_full);
		vec4 small = texture(effect_tex, mirror_uv(uv));
		if (b < 1.0 && r_full >= 0.3) {
			vec2 full_px = 1.0 / (tex_size * 2.0);
			float side = sign(f);
			vec4 sum = vec4(0.0);
			float ws = 0.0;
			for (int i = 0; i < 24; i++) {
				float q = sqrt((float(i) + 0.5) / 24.0);
				float th = float(i) * 2.39996323;
				vec4 sm = texture(effect_tex, mirror_uv(uv + vec2(cos(th), sin(th)) * q * r_full * full_px));
				float w = shape_w(q, side);
				sum += sm * w;
				ws += w;
			}
			small = sum / ws;
		}
		COLOR = b > 0.0 ? mix(small, texture(TEXTURE, UV), b) : small;
	}
}
