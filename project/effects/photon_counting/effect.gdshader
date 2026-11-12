shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float time = 0.0;
uniform float photons : hint_range(0.01, 1000.0) = 1.5;
uniform int sensor : hint_range(0, 1) = 1;
uniform float photon_size : hint_range(1.0, 16.0) = 4.0;
uniform float dark_counts : hint_range(0.0, 1.0) = 0.01;
uniform float gain : hint_range(0.1, 4.0) = 1.0;
uniform bool animate = true;
uniform int seed = 0;

float hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float poisson(float lam, vec3 key) {
	if (lam <= 0.0) {
		return 0.0;
	}
	if (lam > 14.0) {
		float u1 = max(hash(key + vec3(1.7, 0.0, 0.0)), 1e-6);
		float u2 = hash(key + vec3(0.0, 2.3, 0.0));
		float g = sqrt(-2.0 * log(u1)) * cos(6.2831853 * u2);
		return max(floor(lam + sqrt(lam) * g + 0.5), 0.0);
	}
	float L = exp(-lam);
	float p = 1.0;
	float k = 0.0;
	for (int i = 0; i < 40; i++) {
		p *= hash(key + vec3(float(i) * 3.17, float(i) * 1.31, 0.77));
		if (p <= L) {
			break;
		}
		k += 1.0;
	}
	return k;
}

vec3 to_lin(vec3 c) {
	return pow(max(c, vec3(0.0)), vec3(2.2));
}

vec3 counts(vec2 cell, vec3 lin, float frame, float area) {
	vec3 lam = lin * photons * area + dark_counts * area;
	vec3 k;
	if (sensor == 1) {
		float y = dot(lam, vec3(0.2126, 0.7152, 0.0722));
		k = vec3(poisson(y, vec3(cell, frame + float(seed) * 7.13)));
	} else {
		for (int c = 0; c < 3; c++) {
			k[c] = poisson(lam[c], vec3(cell + vec2(float(c) * 101.3, float(c) * 57.1), frame + float(seed) * 7.13));
		}
	}
	return k;
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float a = src.a;
	float frame = animate ? floor(time * 120.0) : 0.0;
	float s = max(photon_size * px_scale, 1.0);
	vec2 pix = UV * tex_size;
	vec3 outc;
	if (s < 1.5) {
		vec2 cell = floor(pix);
		vec3 lin = to_lin(src.rgb / max(a, 1e-4));
		vec3 k = counts(cell, lin, frame, 1.0);
		outc = k / max(photons, 1e-4) * gain;
	} else {
		vec2 cid = floor(pix / s);
		float sig = s * 0.45;
		vec3 acc = vec3(0.0);
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 c = cid + vec2(float(i), float(j));
				vec2 cuv = (c + 0.5) * s / tex_size;
				vec4 cs = texture(TEXTURE, clamp(cuv, vec2(0.0), vec2(1.0)));
				vec3 lin = to_lin(cs.rgb / max(cs.a, 1e-4));
				vec3 k = counts(c, lin, frame, 1.0);
				for (int ch = 0; ch < 3; ch++) {
					float n = min(k[ch], 6.0);
					float extra = k[ch] - n;
					for (int e = 0; e < 6; e++) {
						if (float(e) >= n) {
							break;
						}
						vec2 r = vec2(hash(vec3(c, frame + float(e) * 13.1 + float(ch) * 3.3)), hash(vec3(c.yx, frame + float(e) * 7.9 + float(ch) * 5.1)));
						vec2 ep = (c + r) * s;
						vec2 d = pix - ep;
						acc[ch] += exp(-dot(d, d) / (2.0 * sig * sig)) / (6.2831853 * sig * sig) * s * s;
					}
					if (extra > 0.0) {
						vec2 d = pix - (c + 0.5) * s;
						acc[ch] += extra * exp(-dot(d, d) / (2.0 * s * s * 0.36)) / (6.2831853 * s * s * 0.36) * s * s;
					}
				}
			}
		}
		outc = acc / max(photons, 1e-4) * gain;
	}
	outc = pow(clamp(outc, 0.0, 1.0), vec3(1.0 / 2.2));
	COLOR = vec4(outc * a, a);
}
