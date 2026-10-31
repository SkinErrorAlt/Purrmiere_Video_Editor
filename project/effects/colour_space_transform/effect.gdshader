shader_type canvas_item;
render_mode blend_disabled;

uniform int in_gamut : hint_range(0, 7) = 0;
uniform int in_curve : hint_range(0, 8) = 0;
uniform int out_gamut : hint_range(0, 7) = 3;
uniform int out_curve : hint_range(0, 8) = 5;
uniform int highlights : hint_range(0, 1) = 1;
uniform float exposure : hint_range(-4.0, 4.0) = 0.0;

const float LN10 = 2.302585093;

float decode(float v, int curve) {
	if (curve == 0) {
		return v < 0.081 ? v / 4.5 : pow((max(v, 0.0) + 0.099) / 1.099, 1.0 / 0.45);
	}
	if (curve == 1) {
		return v <= 0.04045 ? v / 12.92 : pow((max(v, 0.0) + 0.055) / 1.055, 2.4);
	}
	if (curve == 2) {
		return pow(max(v, 0.0), 2.2);
	}
	if (curve == 3) {
		return pow(max(v, 0.0), 2.4);
	}
	if (curve == 4) {
		return v;
	}
	if (curve == 5) {
		return v > 0.149658 ? (exp((v - 0.385537) / 0.247190 * LN10) - 0.052272) / 5.555556 : (v - 0.092809) / 5.367655;
	}
	if (curve == 6) {
		return v >= 171.2102946929 / 1023.0 ? exp((v * 1023.0 - 420.0) / 261.5 * LN10) * 0.19 - 0.01 : (v * 1023.0 - 95.0) * 0.01125 / (171.2102946929 - 95.0);
	}
	if (curve == 7) {
		return v < 0.181 ? (v - 0.125) / 5.6 : exp((v - 0.598206) / 0.241514 * LN10) - 0.00873;
	}
	return v <= 0.155251141552511 ? (v - 0.0729055341958355) / 10.5402377416545 : exp2(v * 17.52 - 9.72);
}

float encode(float x, int curve) {
	if (curve == 0) {
		return x < 0.018 ? x * 4.5 : 1.099 * pow(x, 0.45) - 0.099;
	}
	if (curve == 1) {
		return x <= 0.0031308 ? x * 12.92 : 1.055 * pow(x, 1.0 / 2.4) - 0.055;
	}
	if (curve == 2) {
		return pow(max(x, 0.0), 1.0 / 2.2);
	}
	if (curve == 3) {
		return pow(max(x, 0.0), 1.0 / 2.4);
	}
	if (curve == 4) {
		return x;
	}
	if (curve == 5) {
		return x > 0.010591 ? 0.247190 * log(5.555556 * x + 0.052272) / LN10 + 0.385537 : 5.367655 * x + 0.092809;
	}
	if (curve == 6) {
		return x >= 0.01125 ? (420.0 + log((x + 0.01) / 0.19) / LN10 * 261.5) / 1023.0 : (x * (171.2102946929 - 95.0) / 0.01125 + 95.0) / 1023.0;
	}
	if (curve == 7) {
		return x < 0.01 ? 5.6 * x + 0.125 : 0.241514 * log(x + 0.00873) / LN10 + 0.598206;
	}
	return x <= 0.0078125 ? 10.5402377416545 * x + 0.0729055341958355 : (log2(x) + 9.72) / 17.52;
}

void primaries(int g, out vec2 r, out vec2 gr, out vec2 b, out vec2 w) {
	w = vec2(0.3127, 0.3290);
	if (g == 1) {
		r = vec2(0.708, 0.292);
		gr = vec2(0.170, 0.797);
		b = vec2(0.131, 0.046);
	} else if (g == 2) {
		r = vec2(0.680, 0.320);
		gr = vec2(0.265, 0.690);
		b = vec2(0.150, 0.060);
	} else if (g == 3) {
		r = vec2(0.6840, 0.3130);
		gr = vec2(0.2210, 0.8480);
		b = vec2(0.0861, -0.1020);
	} else if (g == 4) {
		r = vec2(0.766, 0.275);
		gr = vec2(0.225, 0.800);
		b = vec2(0.089, -0.087);
	} else if (g == 5) {
		r = vec2(0.730, 0.280);
		gr = vec2(0.165, 0.840);
		b = vec2(0.100, -0.030);
	} else if (g == 6) {
		r = vec2(0.7347, 0.2653);
		gr = vec2(0.0, 1.0);
		b = vec2(0.0001, -0.0770);
		w = vec2(0.32168, 0.33767);
	} else if (g == 7) {
		r = vec2(0.713, 0.293);
		gr = vec2(0.165, 0.830);
		b = vec2(0.128, 0.044);
		w = vec2(0.32168, 0.33767);
	} else {
		r = vec2(0.64, 0.33);
		gr = vec2(0.30, 0.60);
		b = vec2(0.15, 0.06);
	}
}

vec3 xyz_of(vec2 xy) {
	return vec3(xy.x / xy.y, 1.0, (1.0 - xy.x - xy.y) / xy.y);
}

mat3 to_xyz_d65(int g) {
	vec2 r;
	vec2 gr;
	vec2 b;
	vec2 w;
	primaries(g, r, gr, b, w);
	mat3 p = mat3(xyz_of(r), xyz_of(gr), xyz_of(b));
	vec3 s = inverse(p) * xyz_of(w);
	mat3 m = mat3(p[0] * s.x, p[1] * s.y, p[2] * s.z);
	if (abs(w.x - 0.3127) > 0.001) {
		mat3 brad = mat3(vec3(0.8951, -0.7502, 0.0389), vec3(0.2664, 1.7135, -0.0685), vec3(-0.1614, 0.0367, 1.0296));
		vec3 src = brad * xyz_of(w);
		vec3 dst = brad * xyz_of(vec2(0.3127, 0.3290));
		mat3 scale = mat3(vec3(dst.x / src.x, 0.0, 0.0), vec3(0.0, dst.y / src.y, 0.0), vec3(0.0, 0.0, dst.z / src.z));
		m = inverse(brad) * scale * brad * m;
	}
	return m;
}

float shoulder(float m) {
	return m <= 0.8 ? m : 0.8 + 0.2 * tanh((m - 0.8) / 0.2);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 v = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 lin = vec3(decode(v.r, in_curve), decode(v.g, in_curve), decode(v.b, in_curve)) * exp2(exposure);
	if (in_gamut != out_gamut) {
		lin = inverse(to_xyz_d65(out_gamut)) * (to_xyz_d65(in_gamut) * lin);
	}
	if (out_curve <= 3) {
		lin = max(lin, vec3(0.0));
		float m = max(lin.r, max(lin.g, lin.b));
		if (highlights == 1 && m > 0.8) {
			lin *= shoulder(m) / m;
		}
	}
	vec3 outc = vec3(encode(lin.r, out_curve), encode(lin.g, out_curve), encode(lin.b, out_curve));
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
