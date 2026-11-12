shader_type canvas_item;
render_mode blend_disabled;

uniform float melt : hint_range(0.0, 1.0) = 0.5;
uniform float lumps : hint_range(0.0, 1.0) = 0.7;
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash11(i), hash11(i + 1.0), u) * 2.0 - 1.0;
}

float mcol(float x) {
	float sd = float(seed) * 5.17;
	float n = noise1(x * 3.1 + sd) * 0.6 + noise1(x * 7.7 + sd * 2.3) * 0.3 + noise1(x * 17.0 + sd * 3.1) * 0.1;
	return clamp(melt * (1.0 + lumps * 0.6 * n), 0.0, 1.0);
}

float gbase(float u, float mx) {
	float hgt = 1.0 - 0.7 * mx;
	float p = 1.0 + 1.3 * mx;
	return mix(u, hgt * pow(max(u, 0.0), p), mx);
}

float gslope(float u, float mx) {
	float hgt = 1.0 - 0.7 * mx;
	float p = 1.0 + 1.3 * mx;
	return mix(1.0, hgt * p * pow(max(u, 0.001), p - 1.0), mx);
}

float gfun(float u, float mx, float x) {
	float g = gbase(u, mx);
	float cx = floor(x * 6.0);
	float sd = float(seed) * 3.97;
	for (int k = -1; k <= 1; k++) {
		float c = cx + float(k);
		for (int row = 0; row < 3; row++) {
			float id = c * 17.0 + float(row) * 5.0 + sd;
			if (hash11(id + 7.7) > 0.62) {
				continue;
			}
			float xi = (c + 0.5 + 0.8 * (hash11(id + 0.3) - 0.5)) / 6.0;
			float wi = (0.22 + 0.6 * hash11(id + 1.1)) / 6.0;
			float ui = 0.16 + 0.28 * float(row) + 0.22 * (hash11(id + 2.3) - 0.5);
			float si = 0.045 + 0.075 * hash11(id + 3.7);
			float amax = 0.5 * si * gslope(ui, mx) / 0.75;
			float ai = amax * smoothstep(0.0, 0.35, melt) * lumps * (0.5 + 0.5 * hash11(id + 4.9)) * exp(-pow((x - xi) / wi, 2.0));
			g -= ai * smoothstep(ui - si, ui + si, u);
		}
	}
	return g;
}

void fragment() {
	float x = UV.x;
	float uw = 1.0 - UV.y;
	float mx = mcol(x);
	float top = gfun(1.0, mx, x);
	float lo = 0.0;
	float hi = 1.0;
	for (int i = 0; i < 13; i++) {
		float mid = 0.5 * (lo + hi);
		if (gfun(mid, mx, x) < uw) {
			lo = mid;
		} else {
			hi = mid;
		}
	}
	float u = 0.5 * (lo + hi);
	float texel = 1.0 / max(tex_size.y, 1.0);
	float cover = clamp((top - uw) / texel + 0.5, 0.0, 1.0);
	float v = clamp(1.0 - u, 0.0, 1.0);
	float vh = floor(v * 255.0) / 255.0;
	COLOR = vec4(vh, fract(v * 255.0), cover, 1.0);
}
