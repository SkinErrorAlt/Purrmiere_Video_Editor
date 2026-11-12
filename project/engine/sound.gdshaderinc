uniform float snd_level = 0.0;
uniform float snd_bass = 0.0;
uniform float snd_mid = 0.0;
uniform float snd_treble = 0.0;
uniform float snd_voice = 0.0;
uniform float snd_bright = 0.5;
uniform float snd_noise = 0.0;
uniform float snd_sustain = 0.0;
uniform float snd_level_slow = 0.0;
uniform float snd_voice_slow = 0.0;
uniform float snd_hit = 0.0;
uniform float snd_hit_age = 1000.0;
uniform float snd_hit_strength = 0.0;
uniform float snd_hit_seed = 0.0;
uniform float snd_hit_low = 0.0;
uniform float snd_hits = 0.0;
uniform float snd_hit_sum = 0.0;
uniform float snd_quiet = 0.0;
uniform float snd_dose = 0.0;
uniform float snd_hits_n = 0.0;
uniform sampler2D snd_hits_tex : filter_nearest, repeat_disable;
uniform sampler2D snd_past_tex : filter_linear, repeat_disable;

vec4 snd_hit_at(int i) {
	return texelFetch(snd_hits_tex, ivec2(i, 0), 0);
}

vec4 snd_past(float back) {
	float w = float(textureSize(snd_past_tex, 0).x);
	float u = (clamp(back, 0.0, 1.0) * (w - 1.0) + 0.5) / max(w, 1.0);
	return texture(snd_past_tex, vec2(u, 0.5));
}

float snd_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec2 snd_hash2(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

float snd_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = snd_hash(i);
	float b = snd_hash(i + vec2(1.0, 0.0));
	float c = snd_hash(i + vec2(0.0, 1.0));
	float d = snd_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float snd_fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += a * snd_vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return s;
}
