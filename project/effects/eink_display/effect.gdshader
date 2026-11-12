shader_type canvas_item;
render_mode blend_disabled;

uniform int panel : hint_range(0, 2) = 0;
uniform float pixel : hint_range(1.0, 12.0) = 2.0;
uniform int dither : hint_range(0, 2) = 0;
uniform float contrast : hint_range(0.0, 1.0) = 0.5;
uniform float boost : hint_range(0.5, 2.0) = 1.15;
uniform float grain : hint_range(0.0, 1.0) = 0.5;
uniform float front_light : hint_range(0.0, 1.0) = 0.35;
uniform float warmth : hint_range(0.0, 1.0) = 0.3;
uniform float refresh : hint_range(0.0, 1.0) = 0.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size;
uniform float px_scale;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float bayer8(vec2 c) {
	ivec2 p = ivec2(mod(c, 8.0));
	int x = p.x;
	int y = p.y;
	int v = 0;
	int xy = x ^ y;
	v |= ((xy & 1) << 5) | ((x & 1) << 4) | (((xy >> 1) & 1) << 3) | (((x >> 1) & 1) << 2) | (((xy >> 2) & 1) << 1) | ((x >> 2) & 1);
	return (float(v) + 0.5) / 64.0;
}

float blue(vec2 c) {
	float a = fract(52.9829189 * fract(dot(c, vec2(0.06711056, 0.00583715))));
	float b = hash12(c * 1.37 + 17.0);
	return fract(a + 0.18 * (b - 0.5) + 0.5);
}

vec3 sample_cell(sampler2D tex, vec2 cell_px, float pix, vec2 size, out float alpha) {
	vec2 c = (cell_px + 0.5) * pix;
	float o = pix * 0.25;
	vec4 s = texture(tex, clamp((c + vec2(-o, -o)) / size, vec2(0.0), vec2(1.0)));
	s += texture(tex, clamp((c + vec2(o, -o)) / size, vec2(0.0), vec2(1.0)));
	s += texture(tex, clamp((c + vec2(-o, o)) / size, vec2(0.0), vec2(1.0)));
	s += texture(tex, clamp((c + vec2(o, o)) / size, vec2(0.0), vec2(1.0)));
	s *= 0.25;
	alpha = s.a;
	return s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
}

float quantize(float v, float levels, float d) {
	return clamp(floor(v * (levels - 1.0) + d) / (levels - 1.0), 0.0, 1.0);
}

float refresh_state(float q, float r, float jitter) {
	if (r <= 0.0 || r >= 1.0) {
		return q;
	}
	if (r < 0.14) {
		float k = floor(r / 0.14 * 4.0) / 3.0;
		return mix(q, 1.0 - q, clamp(k, 0.0, 1.0));
	}
	if (r < 0.28) {
		float k = floor((r - 0.14) / 0.14 * 4.0) / 3.0;
		return mix(1.0 - q, 0.0, clamp(k, 0.0, 1.0));
	}
	if (r < 0.42) {
		float k = floor((r - 0.28) / 0.14 * 4.0) / 3.0;
		return mix(0.0, 1.0, clamp(k, 0.0, 1.0));
	}
	float t = (r - 0.42) / 0.58;
	float dev = clamp(t * 1.35 - jitter * 0.35, 0.0, 1.0);
	dev = floor(dev * 9.0) / 9.0;
	float residue = (1.0 - q) * 0.12 * (1.0 - t);
	return clamp(mix(1.0, q, dev) - residue, 0.0, 1.0);
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float a = src.a;
	vec2 size = max(tex_size, vec2(1.0));
	float pix = max(pixel * max(px_scale, 0.0001), 0.5);
	vec2 p = UV * size;
	vec2 cell = floor(p / pix);
	float sub = 0.0;
	float ca = 0.0;
	vec3 rgb = vec3(0.0);
	if (panel == 2) {
		sub = mod(cell.x + cell.y, 3.0);
		vec2 c3 = (cell + 0.5) * pix;
		vec4 s3 = texture(TEXTURE, clamp(c3 / size, vec2(0.0), vec2(1.0)));
		s3 += texture(TEXTURE, clamp((c3 + vec2(-pix, 0.0)) / size, vec2(0.0), vec2(1.0)));
		s3 += texture(TEXTURE, clamp((c3 + vec2(0.0, pix)) / size, vec2(0.0), vec2(1.0)));
		s3 /= 3.0;
		rgb = s3.a > 0.0001 ? s3.rgb / s3.a : vec3(0.0);
	} else {
		rgb = sample_cell(TEXTURE, cell, pix, size, ca);
	}
	float v = 0.0;
	if (panel == 2) {
		vec3 chan = sub < 0.5 ? vec3(1.0, 0.0, 0.0) : (sub < 1.5 ? vec3(0.0, 1.0, 0.0) : vec3(0.0, 0.0, 1.0));
		float y = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
		v = mix(y, dot(rgb, chan), 0.9);
	} else {
		v = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	}
	v = clamp((v - 0.5) * boost + 0.5, 0.0, 1.0);
	v = pow(v, 0.9);
	vec2 dc = cell + vec2(float(seed) * 7.0, float(seed) * 3.0);
	float d = 0.5;
	if (dither == 0) {
		d = blue(dc);
	} else if (dither == 1) {
		d = bayer8(dc);
	}
	float levels = panel == 1 ? 2.0 : 16.0;
	float q = quantize(v, levels, d);
	float jitter = hash12(cell + 31.0 + float(seed));
	q = refresh_state(q, refresh, jitter);
	float white = mix(0.7, 0.86, contrast);
	float black = mix(0.24, 0.07, contrast);
	float refl = mix(black, white, q);
	float fine = vnoise(p / max(1.3 * px_scale, 0.3) + float(seed) * 13.1);
	float mid = vnoise(p / max(7.0 * px_scale, 0.5) + 41.0);
	float cloud = vnoise(p / max(140.0 * px_scale, 1.0) + 7.0) * 0.6 + vnoise(p / max(45.0 * px_scale, 1.0) + 3.0) * 0.4;
	float speck = step(0.93, hash12(floor(p / max(px_scale, 0.3)) + 5.0 + float(seed)));
	float tex = 1.0 + grain * ((fine - 0.5) * 0.07 + (mid - 0.5) * 0.05 + (cloud - 0.5) * 0.06);
	refl *= tex;
	refl += grain * speck * (1.0 - q) * 0.05;
	refl -= grain * step(0.95, hash12(floor(p / max(px_scale, 0.3)) + 9.0)) * q * 0.04;
	vec3 paper = vec3(refl) * vec3(1.0, 0.995, 0.97);
	if (panel == 2) {
		vec3 f = sub < 0.5 ? vec3(1.0, 0.36, 0.32) : (sub < 1.5 ? vec3(0.42, 1.0, 0.4) : vec3(0.36, 0.46, 1.0));
		f = f / dot(f, vec3(0.2126, 0.7152, 0.0722)) * 0.8;
		vec2 local = fract(p / pix);
		float edge = smoothstep(0.0, 0.15, local.x) * smoothstep(1.0, 0.85, local.x) * smoothstep(0.0, 0.15, local.y) * smoothstep(1.0, 0.85, local.y);
		paper *= mix(vec3(0.85), f, 0.8) * mix(0.9, 1.0, edge);
	}
	vec2 uvn = UV;
	float edge_glow = exp(-(1.0 - uvn.y) * 9.0);
	float scallop = 0.5 + 0.5 * cos(uvn.x * 6.2832 * 7.0);
	float bands = exp(-(1.0 - uvn.y) * 30.0) * scallop;
	float spread = 0.82 + 0.18 * (1.0 - abs(uvn.x - 0.5) * 2.0) * (0.6 + 0.4 * uvn.y);
	float blot = vnoise(uvn * vec2(5.0, 3.0) + 11.0);
	float lamp = front_light * (0.55 * spread + 0.35 * edge_glow + 0.25 * bands + 0.08 * (blot - 0.5));
	vec3 light_col = mix(vec3(0.96, 0.98, 1.0), vec3(1.0, 0.78, 0.5), warmth);
	vec3 outc = paper * (vec3(1.0) * (1.0 - front_light * 0.35) + light_col * lamp * 1.1);
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
