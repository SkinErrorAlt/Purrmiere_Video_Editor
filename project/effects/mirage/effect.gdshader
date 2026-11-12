shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float time = 0.0;
uniform int mode : hint_range(0, 2) = 0;
uniform float horizon : hint_range(0.0, 1.0) = 0.6;
uniform float heat : hint_range(0.0, 0.3) = 0.08;
uniform float layer : hint_range(0.05, 3.0) = 0.35;
uniform float shimmer : hint_range(0.0, 1.0) = 0.5;
uniform float shimmer_size : hint_range(0.2, 5.0) = 1.0;
uniform float wind : hint_range(-4.0, 4.0) = 0.6;
uniform float speed : hint_range(0.0, 4.0) = 1.0;
uniform int seed = 0;

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

float bump(float z) {
	return exp(-z * z);
}

float dndh(float h, float A, float L) {
	if (mode == 0) {
		return A / L * exp(-max(h, 0.0) / L);
	}
	if (mode == 1) {
		float w = max(L * 0.35, 0.03);
		return -A / w * bump((h - L) / w) * 1.1284;
	}
	float w1 = max(L * 0.12, 0.02);
	float g = -A / w1 * (bump((h - L * 0.75) / w1) + 0.8 * bump((h - L * 1.25) / w1)) * 1.1284 * 0.6;
	return g - A * 0.5 / max(L * 0.5, 0.02) * exp(-max(h, 0.0) / max(L * 0.5, 0.02));
}

void fragment() {
	const float X = 5000.0;
	const float TH = 0.02;
	const int N = 64;
	float h0 = 1.0;
	float b = heat * TH;
	float L = layer;
	float A;
	if (mode == 0) {
		A = b * b / (2.0 * max(1.0 - exp(-h0 / L), 1e-3));
	} else {
		A = b * b * 0.5;
	}
	float live = clamp(heat / 0.04, 0.0, 1.0) * shimmer;
	vec2 sd = vec2(float(seed) * 17.31, float(seed) * 5.17);
	float sz = 1.0 / shimmer_size;
	float tt = time * speed;
	vec2 np = vec2(UV.x * 18.0 * sz - tt * wind * 0.6, UV.y * 55.0 * sz - tt * 1.3) + sd;
	float n1 = vnoise(np) * 0.65 + vnoise(np * vec2(2.3, 2.1) + vec2(tt * 0.9, 3.7)) * 0.35;
	vec2 np2 = vec2(UV.x * 9.0 * sz + tt * wind * 0.3, UV.y * 28.0 * sz + tt * 2.1) + sd.yx;
	float n2 = vnoise(np2);
	float Aj = A * (1.0 + live * 1.5 * (n1 - 0.5));
	float s = UV.y - horizon;
	float s_acc = 0.0;
	for (int r = 0; r < 3; r++) {
		float jit = (float(r) - 1.0) * 0.6 / max(tex_size.y, 1.0);
		float Ar = Aj * (1.0 + live * 0.25 * (float(r) - 1.0) * (n2 - 0.5));
		float p = -(s + jit) * TH;
		float h = h0;
		float x = 0.0;
		float dx = X / float(N);
		float s_src = 0.0;
		bool ground = false;
		for (int i = 0; i < N; i++) {
			float a1 = dndh(h, Ar, L);
			float pm = p + a1 * dx * 0.5;
			float hn = h + pm * dx;
			if (hn <= 0.0) {
				float fr = h / max(h - hn, 1e-9);
				float xg = x + fr * dx;
				s_src = h0 / (max(xg, 1e-3) * TH);
				ground = true;
				break;
			}
			float a2 = dndh(hn, Ar, L);
			p = pm + a2 * dx * 0.5;
			h = hn;
			x += dx;
		}
		if (!ground) {
			s_src = (h0 - h) / (X * TH);
		}
		s_acc += s_src;
	}
	float s_mid = s_acc / 3.0;
	float band = clamp(1.0 - abs(s) / max(heat * 3.0, 1e-3), 0.0, 1.0);
	float jx = live * (n2 - 0.5) * 0.0025 * (0.3 + band);
	float jy = live * (n1 - 0.5) * heat * 0.08 * band;
	float spread = band * heat * 0.05 * (0.4 + live);
	vec4 acc = vec4(0.0);
	for (int t = 0; t < 4; t++) {
		float o = (float(t) - 1.5) / 1.5;
		vec2 suv = vec2(UV.x + jx + o * 0.0008 * band * live, horizon + s_mid + jy + o * spread);
		acc += texture(TEXTURE, clamp(suv, vec2(0.0), vec2(1.0)));
	}
	vec4 one = texture(TEXTURE, clamp(vec2(UV.x + jx, horizon + s_mid + jy), vec2(0.0), vec2(1.0)));
	COLOR = mix(one, acc * 0.25, clamp(band * 4.0, 0.0, 1.0));
}
