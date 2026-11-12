
vec2 sim_pack(float v) {
	float q = floor(clamp(v, 0.0, 1.0) * 65535.0 + 0.5);
	float hi = floor(q / 256.0);
	return vec2(hi, q - hi * 256.0) / 255.0;
}

float sim_unpack(vec2 p) {
	return (floor(p.x * 255.0 + 0.5) * 256.0 + floor(p.y * 255.0 + 0.5)) / 65535.0;
}

float sim_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 sim_hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float sim_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = sim_hash(i);
	float b = sim_hash(i + vec2(1.0, 0.0));
	float c = sim_hash(i + vec2(0.0, 1.0));
	float d = sim_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float sim_fbm(vec2 p, int octaves) {
	float s = 0.0;
	float a = 0.5;
	float n = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i >= octaves) {
			break;
		}
		s += a * sim_noise(p);
		n += a;
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return s / n;
}

float sim_luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float sim_field(sampler2D tex, vec2 uv) {
	vec2 sz = vec2(textureSize(tex, 0));
	vec2 p = uv * sz - 0.5;
	vec2 i = floor(p);
	vec2 f = p - i;
	ivec2 hi = ivec2(sz) - 1;
	ivec2 a = clamp(ivec2(i), ivec2(0), hi);
	ivec2 b = clamp(ivec2(i) + ivec2(1, 0), ivec2(0), hi);
	ivec2 c = clamp(ivec2(i) + ivec2(0, 1), ivec2(0), hi);
	ivec2 d = clamp(ivec2(i) + ivec2(1, 1), ivec2(0), hi);
	float va = sim_unpack(texelFetch(tex, a, 0).rg);
	float vb = sim_unpack(texelFetch(tex, b, 0).rg);
	float vc = sim_unpack(texelFetch(tex, c, 0).rg);
	float vd = sim_unpack(texelFetch(tex, d, 0).rg);
	return mix(mix(va, vb, f.x), mix(vc, vd, f.x), f.y);
}

float sim_field_ba(sampler2D tex, vec2 uv) {
	vec2 sz = vec2(textureSize(tex, 0));
	vec2 p = uv * sz - 0.5;
	vec2 i = floor(p);
	vec2 f = p - i;
	ivec2 hi = ivec2(sz) - 1;
	ivec2 a = clamp(ivec2(i), ivec2(0), hi);
	ivec2 b = clamp(ivec2(i) + ivec2(1, 0), ivec2(0), hi);
	ivec2 c = clamp(ivec2(i) + ivec2(0, 1), ivec2(0), hi);
	ivec2 d = clamp(ivec2(i) + ivec2(1, 1), ivec2(0), hi);
	float va = sim_unpack(texelFetch(tex, a, 0).ba);
	float vb = sim_unpack(texelFetch(tex, b, 0).ba);
	float vc = sim_unpack(texelFetch(tex, c, 0).ba);
	float vd = sim_unpack(texelFetch(tex, d, 0).ba);
	return mix(mix(va, vb, f.x), mix(vc, vd, f.x), f.y);
}
