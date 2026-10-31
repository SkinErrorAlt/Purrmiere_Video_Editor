shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.1, 3.0) = 0.5;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.45);
uniform float threshold : hint_range(0.0, 1.0) = 0.55;
uniform int rays : hint_range(4, 64) = 22;
uniform float spin : hint_range(-1.0, 1.0) = 0.1;

const int TAPS = 40;

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

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float ray_noise(float x, float n) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash11(mod(i, n) + 3.0), hash11(mod(i + 1.0, n) + 3.0), u);
}

void fragment() {
	bool is_in = false;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		vec2 asp = vec2(sz.x / sz.y, 1.0);
		vec2 ctr = clamp(centre, vec2(-0.5), vec2(1.5));
		float e = g * g * (3.0 - 2.0 * g);
		vec2 rel = UV - ctr;
		float span = mix(0.12, 0.95, e);
		float jit = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		float thr = clamp(threshold, 0.0, 0.98);
		vec3 acc = vec3(0.0);
		float wsum = 0.0;
		for (int i = 0; i < TAPS; i++) {
			float t = (float(i) + jit) / float(TAPS);
			vec2 uv = UV - rel * span * t;
			vec4 s = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
			vec3 rgb = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
			float l = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
			float b = max(l - thr, 0.0) / (1.0 - thr) * s.a;
			float w = 1.0 - t * 0.7;
			acc += rgb * b * w;
			wsum += w;
		}
		acc /= max(wsum, 0.0001);
		vec2 ra = rel * asp;
		float r = length(ra);
		float n = float(clamp(rays, 4, 64));
		float turn = clamp(spin, -1.0, 1.0) * e * (is_in ? -1.0 : 1.0);
		float ang = (atan(ra.y, ra.x) / 6.2831853 + 0.5 - turn) * n;
		float streak = pow(ray_noise(ang, n), 3.0) * 0.8 + pow(ray_noise(ang * 2.0 + 0.5, n * 2.0), 4.0) * 0.4;
		float reach = 0.15 + 1.4 * e;
		float fall = exp(-r / max(reach, 0.01)) * smoothstep(0.0, 0.03 + 0.1 * e, r);
		float core = exp(-r * r / max(0.002 + 0.03 * e * e, 0.0001));
		vec3 light = acc * 3.0 + vec3(streak * fall * 1.2 + core);
		COLOR = vec4(light, 1.0);
	}
}
