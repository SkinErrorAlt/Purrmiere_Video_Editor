shader_type canvas_item;
render_mode blend_disabled;

uniform int lamp : hint_range(0, 9) = 1;
uniform float wavelength : hint_range(400.0, 700.0) = 589.0;
uniform int balance : hint_range(0, 1) = 1;
uniform float exposure : hint_range(-4.0, 4.0) = 0.0;
uniform float purity : hint_range(0.0, 1.0) = 1.0;


const vec3 CMF40[40] = vec3[](vec3(0.00000, 0.00005, 0.00064), vec3(0.00000, 0.00001, 0.00198), vec3(0.00032, 0.00000, 0.00591), vec3(0.00303, 0.00000, 0.02003), vec3(0.00697, 0.00000, 0.06389), vec3(0.01014, 0.00000, 0.13530), vec3(0.01524, 0.00000, 0.16914), vec3(0.00991, 0.00000, 0.17338), vec3(0.00000, 0.00000, 0.16199), vec3(0.00000, 0.00317, 0.12447), vec3(0.00000, 0.01710, 0.07617), vec3(0.00000, 0.03360, 0.04120), vec3(0.00000, 0.05408, 0.02007), vec3(0.00000, 0.08050, 0.00582), vec3(0.00000, 0.10931, 0.00000), vec3(0.00000, 0.12793, 0.00000), vec3(0.00000, 0.13136, 0.00000), vec3(0.00000, 0.12518, 0.00000), vec3(0.02434, 0.11042, 0.00000), vec3(0.05928, 0.08949, 0.00000), vec3(0.09328, 0.06444, 0.00000), vec3(0.12138, 0.03821, 0.00000), vec3(0.13902, 0.01441, 0.00000), vec3(0.14045, 0.00000, 0.00000), vec3(0.12451, 0.00000, 0.00000), vec3(0.09779, 0.00000, 0.00000), vec3(0.06835, 0.00000, 0.00000), vec3(0.04261, 0.00000, 0.00000), vec3(0.02368, 0.00000, 0.00000), vec3(0.01172, 0.00000, 0.00000), vec3(0.00514, 0.00000, 0.00000), vec3(0.00198, 0.00024, 0.00000), vec3(0.00066, 0.00023, 0.00000), vec3(0.00018, 0.00015, 0.00000), vec3(0.00004, 0.00008, 0.00000), vec3(0.00000, 0.00004, 0.00000), vec3(0.00000, 0.00001, 0.00000), vec3(0.00000, 0.00001, 0.00000), vec3(0.00000, 0.00000, 0.00000), vec3(0.00000, 0.00000, 0.00000));
const vec3 CMF_NORM = vec3(0.05681, 0.08660, 0.09148);
const mat3 CCM = mat3(vec3(1.451005, -0.097262, -0.028913), vec3(-0.397860, 1.203252, -0.122606), vec3(-0.053440, -0.105378, 1.151417));
const float SM[70] = float[](
	1.0000, 1.0000, 0.9999, 0.9993, 0.9992, 0.9998, 1.0000, 1.0000, 1.0000, 1.0000,
	0.9710, 0.9426, 1.0007, 1.0007, 1.0007, 1.0007, 0.1564, 0.0000, 0.0000, 0.0000,
	1.0000, 1.0000, 0.9685, 0.2229, 0.0000, 0.0458, 0.8369, 1.0000, 1.0000, 0.9959,
	0.0001, 0.0000, 0.1088, 0.6651, 1.0000, 1.0000, 0.9996, 0.9586, 0.9685, 0.9840,
	0.1012, 0.0515, 0.0000, 0.0000, 0.0000, 0.0000, 0.8325, 1.0149, 1.0149, 1.0149,
	0.0000, 0.0000, 0.0273, 0.7937, 1.0000, 0.9418, 0.1719, 0.0000, 0.0000, 0.0025,
	1.0000, 1.0000, 0.8916, 0.3323, 0.0000, 0.0000, 0.0003, 0.0369, 0.0483, 0.0496);

vec3 wl_rgb(float l) {
	float t1 = (l - 442.0) * ((l < 442.0) ? 0.0624 : 0.0374);
	float t2 = (l - 599.8) * ((l < 599.8) ? 0.0264 : 0.0323);
	float t3 = (l - 501.1) * ((l < 501.1) ? 0.0490 : 0.0382);
	float x = 0.362 * exp(-0.5 * t1 * t1) + 1.056 * exp(-0.5 * t2 * t2) - 0.065 * exp(-0.5 * t3 * t3);
	float u1 = (l - 568.8) * ((l < 568.8) ? 0.0213 : 0.0247);
	float u2 = (l - 530.9) * ((l < 530.9) ? 0.0613 : 0.0322);
	float y = 0.821 * exp(-0.5 * u1 * u1) + 0.286 * exp(-0.5 * u2 * u2);
	float v1 = (l - 437.0) * ((l < 437.0) ? 0.0845 : 0.0278);
	float v2 = (l - 459.0) * ((l < 459.0) ? 0.0385 : 0.0725);
	float z = 1.217 * exp(-0.5 * v1 * v1) + 0.681 * exp(-0.5 * v2 * v2);
	vec3 c = vec3(3.2406 * x - 1.5372 * y - 0.4986 * z, -0.9689 * x + 1.8758 * y + 0.0415 * z, 0.0557 * x - 0.2040 * y + 1.0570 * z);
	return max(c, vec3(0.0)) * CMF_NORM;
}

float gs(float l, float mu, float s) {
	float t = (l - mu) / s;
	return exp(-0.5 * t * t);
}

float planck(float l, float T) {
	float lm = l * 1e-9;
	float e = exp(0.014388 / (lm * T)) - 1.0;
	float e0 = exp(0.014388 / (560e-9 * T)) - 1.0;
	return pow(560.0 / l, 5.0) * e0 / e;
}

float continuum(float l) {
	if (lamp == 0) {
		return 1.0;
	}
	if (lamp == 2) {
		return 0.9 * gs(l, 568.0, 13.0) + 1.0 * gs(l, 606.0, 17.0) + 0.12 * gs(l, 500.0, 35.0) + 0.04;
	}
	if (lamp == 3) {
		return 0.03;
	}
	if (lamp == 4) {
		return 0.75 * gs(l, 578.0, 62.0) + 0.1 * gs(l, 480.0, 30.0);
	}
	if (lamp == 5) {
		return 0.05;
	}
	if (lamp == 6) {
		return 1.0 * gs(l, 451.0, 11.0) + 0.62 * gs(l, 560.0, 58.0);
	}
	if (lamp == 7) {
		return planck(l, 2800.0);
	}
	if (lamp == 8) {
		return planck(l, 1850.0);
	}
	return 0.0;
}

float refl(float s[10], float l) {
	float x = clamp((l - 397.0) / 34.0, 0.0, 9.0);
	int i = int(floor(x));
	int j = min(i + 1, 9);
	return mix(s[i], s[j], x - float(i));
}

void add_line(inout vec3 acc, inout vec3 wt, float s[10], float l, float w) {
	vec3 c = wl_rgb(l) * w;
	acc += c * refl(s, l);
	wt += c;
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float a = src.a;
	vec3 c = pow(max(src.rgb / max(a, 1e-4), vec3(0.0)), vec3(2.2));
	float s[10];
	int A = 0;
	int B = 0;
	float base;
	float m1;
	float m2;
	if (c.r <= c.g && c.r <= c.b) {
		base = c.r;
		if (c.g <= c.b) { A = 1; B = 6; m1 = c.g - c.r; m2 = c.b - c.g; } else { A = 1; B = 5; m1 = c.b - c.r; m2 = c.g - c.b; }
	} else if (c.g <= c.r && c.g <= c.b) {
		base = c.g;
		if (c.r <= c.b) { A = 2; B = 6; m1 = c.r - c.g; m2 = c.b - c.r; } else { A = 2; B = 4; m1 = c.b - c.g; m2 = c.r - c.b; }
	} else {
		base = c.b;
		if (c.r <= c.g) { A = 3; B = 5; m1 = c.r - c.b; m2 = c.g - c.r; } else { A = 3; B = 4; m1 = c.g - c.b; m2 = c.r - c.g; }
	}
	for (int i = 0; i < 10; i++) {
		s[i] = base * SM[i] + m1 * SM[A * 10 + i] + m2 * SM[B * 10 + i];
	}
	vec3 acc = vec3(0.0);
	vec3 wt = vec3(0.0);
	for (int k = 0; k < 40; k++) {
		float l = 380.0 + float(k) * 10.0;
		float e = continuum(l);
		vec3 w = CMF40[k] * e;
		acc += w * refl(s, l);
		wt += w;
	}
	if (lamp == 1) {
		add_line(acc, wt, s, 589.0, 30.0);
		add_line(acc, wt, s, 589.6, 15.0);
	} else if (lamp == 2) {
		add_line(acc, wt, s, 568.8, 0.6);
		add_line(acc, wt, s, 498.0, 0.3);
		add_line(acc, wt, s, 615.4, 0.5);
	} else if (lamp == 3) {
		add_line(acc, wt, s, 404.7, 3.0);
		add_line(acc, wt, s, 435.8, 8.0);
		add_line(acc, wt, s, 546.1, 10.0);
		add_line(acc, wt, s, 577.5, 8.0);
	} else if (lamp == 4) {
		add_line(acc, wt, s, 404.7, 1.2);
		add_line(acc, wt, s, 435.8, 3.0);
		add_line(acc, wt, s, 546.1, 4.0);
		add_line(acc, wt, s, 577.5, 1.0);
	} else if (lamp == 5) {
		add_line(acc, wt, s, 611.0, 9.0);
		add_line(acc, wt, s, 544.0, 9.0);
		add_line(acc, wt, s, 487.0, 2.0);
		add_line(acc, wt, s, 435.8, 4.0);
		add_line(acc, wt, s, 404.7, 1.0);
	} else if (lamp == 9) {
		add_line(acc, wt, s, wavelength, 20.0);
	}
	acc = max(CCM * acc, vec3(0.0));
	wt = max(CCM * wt, vec3(0.0));
	vec3 white = max(wt, vec3(1e-6));
	float wy = dot(white, vec3(0.2126, 0.7152, 0.0722));
	vec3 outc;
	if (balance == 0) {
		float mw = max(white.r, max(white.g, white.b));
		float ay = dot(acc, vec3(0.2126, 0.7152, 0.0722)) / max(wy, 1e-6);
		vec3 k = smoothstep(vec3(0.004), vec3(0.06), white / mw);
		outc = mix(vec3(ay), acc / white, k);
	} else {
		outc = acc / max(max(white.r, max(white.g, white.b)), 1e-6);
	}
	vec3 grey = vec3(dot(outc, vec3(0.2126, 0.7152, 0.0722)));
	outc = mix(grey, outc, purity) * exp2(exposure);
	COLOR = vec4(pow(clamp(outc, 0.0, 1.0), vec3(1.0 / 2.2)) * a, a);
}
