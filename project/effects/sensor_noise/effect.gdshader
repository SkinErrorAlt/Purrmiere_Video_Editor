shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float time = 0.0;
uniform float seq_fps = 30.0;
uniform float gain : hint_range(0.0, 9.0) = 5.5;
uniform int sensor = 1;
uniform int balance = 0;
uniform float colour_noise : hint_range(0.0, 1.0) = 0.55;
uniform float blotches : hint_range(0.0, 1.0) = 0.5;
uniform float blotch_size : hint_range(4.0, 60.0) = 16.0;
uniform float columns : hint_range(0.0, 1.0) = 0.35;
uniform float banding : hint_range(0.0, 1.0) = 0.35;
uniform float hot_pixels : hint_range(0.0, 1.0) = 0.1;
uniform int seed = 0;
uniform bool animate = true;

uvec3 pcg3(uvec3 v) {
	v = v * 1664525u + 1013904223u;
	v.x += v.y * v.z;
	v.y += v.z * v.x;
	v.z += v.x * v.y;
	v ^= v >> 16u;
	v.x += v.y * v.z;
	v.y += v.z * v.x;
	v.z += v.x * v.y;
	return v;
}

vec3 rnd3(ivec2 p, uint salt) {
	uvec3 h = pcg3(uvec3(uint(p.x + 65536), uint(p.y + 65536), salt));
	return vec3(h) * (1.0 / 4294967296.0);
}

float gauss(ivec2 p, uint salt) {
	vec3 u = rnd3(p, salt);
	return sqrt(-2.0 * log(max(u.x, 1e-7))) * cos(6.28318530718 * u.y);
}

float green_noise(ivec2 p, uint salt) {
	float n = 0.6 * gauss(p, salt);
	n += 0.2 * gauss(p + ivec2(1, 0), salt) + 0.2 * gauss(p + ivec2(0, 1), salt);
	return n / 0.6633;
}

float lattice_noise(vec2 p, uint salt, float spacing) {
	vec2 q = p / spacing;
	vec2 f = fract(q);
	ivec2 i = ivec2(floor(q));
	float a = gauss(i, salt);
	float b = gauss(i + ivec2(1, 0), salt);
	float c = gauss(i + ivec2(0, 1), salt);
	float d = gauss(i + ivec2(1, 1), salt);
	vec2 w = f * f * (3.0 - 2.0 * f);
	float w00 = (1.0 - w.x) * (1.0 - w.y);
	float w10 = w.x * (1.0 - w.y);
	float w01 = (1.0 - w.x) * w.y;
	float w11 = w.x * w.y;
	float n = a * w00 + b * w10 + c * w01 + d * w11;
	return n / sqrt(w00 * w00 + w10 * w10 + w01 * w01 + w11 * w11);
}

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

float hot_at(ivec2 p, uint salt, float density, out int channel) {
	vec3 u = rnd3(p, salt);
	channel = int(u.y * 3.0);
	return u.x < density ? 0.25 + 0.75 * u.z : 0.0;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float cell = max(px_scale, 1.0);
	float amp = min(px_scale, 1.0);
	vec2 pp = UV * tex_size / cell;
	ivec2 p = ivec2(floor(pp));
	uint frame = animate ? uint(max(floor(time * seq_fps + 0.5), 0.0)) : 0u;
	uint s0 = uint(seed) * 7919u;
	uint fs = s0 + frame * 104729u;
	vec3 gains = balance == 1 ? vec3(1.35, 1.0, 2.7) : vec3(2.0, 1.0, 1.5);
	float well = sensor == 0 ? 60000.0 : (sensor == 2 ? 7000.0 : 28000.0);
	float read_e = sensor == 2 ? 2.2 : 3.2;
	float eff = well / exp2(gain);
	vec3 raw = to_lin(clamp(rgb, 0.0, 1.0)) / gains;
	vec3 sigma = sqrt(max(raw, vec3(0.0)) / eff + vec3(read_e * read_e) / (eff * eff));
	float read_sigma = read_e / eff;
	float ng = green_noise(p, fs + 11u);
	float nr = lattice_noise(pp + vec2(0.5, 0.5), fs + 23u, 2.0);
	float nb = lattice_noise(pp + vec2(1.5, 1.5), fs + 37u, 2.0);
	float shared = ng;
	vec3 n = vec3(mix(shared, nr, colour_noise), mix(shared, ng, colour_noise * 0.3), mix(shared, nb, colour_noise));
	vec3 noisy = raw + n * sigma * amp;
	if (blotches > 0.0) {
		float bs = max(blotch_size * px_scale / cell, 1.0);
		float br = lattice_noise(pp, fs + 51u, bs);
		float bb = lattice_noise(pp + vec2(17.0, 9.0), fs + 67u, bs);
		vec3 bsig = sigma * blotches * 0.9;
		noisy += vec3(br * bsig.r, -0.35 * (br * bsig.r + bb * bsig.b), bb * bsig.b);
	}
	if (columns > 0.0) {
		vec3 u = rnd3(ivec2(p.x, 0), s0 + 91u);
		float off = (u.x - 0.5) * 2.0 + (u.y - 0.5) * 1.0;
		float pair = (u.z - 0.5) * 0.8;
		noisy += vec3(off + pair, off - pair, off + pair) * read_sigma * columns * 1.1;
	}
	if (banding > 0.0) {
		float row = gauss(ivec2(0, p.y), fs + 101u);
		float slow = lattice_noise(vec2(0.0, pp.y), fs + 113u, 9.0);
		noisy += vec3(row * 0.8 + slow * 0.6) * read_sigma * banding * 1.2;
	}
	if (hot_pixels > 0.0) {
		float density = hot_pixels * 0.00025;
		vec3 hot = vec3(0.0);
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				int ch = 0;
				float v = hot_at(p + ivec2(i, j), s0 + 131u, density, ch);
				if (v > 0.0) {
					float w = (i == 0 && j == 0) ? 1.0 : ((i == 0 || j == 0) ? 0.3 : 0.1);
					vec3 m = ch == 0 ? vec3(1.0, 0.25, 0.15) : (ch == 1 ? vec3(0.3, 1.0, 0.3) : vec3(0.2, 0.3, 1.0));
					hot += m * v * w;
				}
			}
		}
		noisy += hot / gains * amp;
	}
	vec3 lin = max(noisy, vec3(0.0)) * gains;
	vec3 outc = clamp(to_srgb(lin), 0.0, 1.0);
	COLOR = vec4(outc * a, a);
}
