shader_type canvas_item;
render_mode blend_disabled;

uniform float snow : hint_range(0.0, 1.0) = 0.6;
uniform float grow_time : hint_range(0.0, 30.0) = 0.0;
uniform float depth : hint_range(2.0, 120.0) = 26.0;
uniform float lumpiness : hint_range(0.0, 1.0) = 0.6;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 w = mod(i, 289.0);
	return mix(mix(hash12(w), hash12(w + vec2(1.0, 0.0)), f.x), mix(hash12(w + vec2(0.0, 1.0)), hash12(w + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float amt = clamp(snow, 0.0, 1.0);
	if (grow_time > 0.0001) {
		amt *= clamp(max(clip_time, 0.0) / grow_time, 0.0, 1.0);
	}
	vec2 pix = UV * sz;
	float sk = mod(float(seed), 997.0);
	vec2 sp = pix / ps;
	float lump = vnoise(vec2(sp.x / 46.0 + sk, sk * 0.3)) * 0.6 + vnoise(vec2(sp.x / 13.0 + sk * 1.7, 4.0)) * 0.4;
	float h = depth * ps * sqrt(amt) * mix(1.0, 0.35 + 1.3 * lump, lumpiness);
	float acc = 0.0;
	float pos = 1.0;
	for (int i = 0; i < 12; i++) {
		float t = float(i) / 11.0;
		vec2 o = vec2(0.0, t * h);
		float e = 0.0;
		for (int k = -3; k <= 3; k++) {
			e += texture(TEXTURE, clamp((pix + o + vec2(float(k) * 1.5, 0.0)) / sz, vec2(0.0), vec2(1.0))).r;
		}
		e = smoothstep(0.25, 0.7, e / 7.0);
		float c = e * (1.0 - pow(t, 1.6));
		if (c > acc) {
			acc = c;
			pos = t;
		}
	}
	acc *= smoothstep(0.0, 0.15, amt);
	COLOR = vec4(acc, pos, 0.0, 1.0);
}
