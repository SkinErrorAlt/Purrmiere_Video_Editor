shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float amount : hint_range(0.0, 100.0) = 8.0;
uniform float bumps : hint_range(0.0, 1.0) = 0.3;
uniform float bump_size : hint_range(4.0, 400.0) = 60.0;
uniform float blur : hint_range(0.0, 1.0) = 0.4;
uniform int seed : hint_range(0, 9999) = 0;
uniform float animate : hint_range(0.0, 30.0) = 0.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 pix = UV * size / ps;
	float frame = animate > 0.0 ? floor(clip_time * animate) : 0.0;
	vec2 sd = vec2(float(seed) * 1.37 + 11.0, frame * 7.13 + 3.0);
	vec2 bump_off = vec2(0.0);
	if (bumps > 0.0) {
		vec2 q = pix / max(bump_size, 1.0) + sd * 0.173;
		float e = 0.35;
		float hx = value_noise(q + vec2(e, 0.0)) - value_noise(q - vec2(e, 0.0));
		float hy = value_noise(q + vec2(0.0, e)) - value_noise(q - vec2(0.0, e));
		bump_off = vec2(hx, hy) * bumps * bump_size;
	}
	int taps = 1 + int(round(clamp(blur, 0.0, 1.0) * 7.0));
	vec2 cell = floor(pix);
	vec4 sum = vec4(0.0);
	for (int i = 0; i < 8; i++) {
		if (i >= taps) {
			break;
		}
		vec2 h = hash22(cell + sd + vec2(float(i) * 17.31, float(i) * 5.77));
		float rr = sqrt(h.x) * amount;
		float ang = h.y * 6.28318530718;
		vec2 jitter = vec2(cos(ang), sin(ang)) * rr;
		vec2 uv = UV + (jitter + bump_off) * ps / size;
		sum += texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	}
	COLOR = sum / float(taps);
}
