shader_type canvas_item;
render_mode blend_disabled;

uniform int source : hint_range(0, 9) = 0;
uniform float exposure : hint_range(-4.0, 4.0) = 0.0;
uniform int tone : hint_range(0, 2) = 1;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform bool full_range = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

const mat3 S_GAMUT3_CINE_TO_709 = mat3(vec3(1.62694741, -0.17851553, -0.04443612), vec3(-0.54013854, 1.41794093, -0.19591997), vec3(-0.08680887, -0.23942540, 1.24035608));
const mat3 S_GAMUT3_TO_709 = mat3(vec3(1.87791513, -0.17680698, -0.02620113), vec3(-0.79416876, 1.35099962, -0.14842226), vec3(-0.08374637, -0.17419264, 1.17462339));
const mat3 AWG3_TO_709 = mat3(vec3(1.61752344, -0.07057274, -0.02110173), vec3(-0.53728662, 1.33461306, -0.22695388), vec3(-0.08023681, -0.26404032, 1.24805560));
const mat3 AWG4_TO_709 = mat3(vec3(1.89312344, -0.20570036, -0.01270574), vec3(-0.78088150, 1.34025749, -0.15218488), vec3(-0.11224194, -0.13455713, 1.16489062));
const mat3 V_GAMUT_TO_709 = mat3(vec3(1.80657588, -0.17009034, -0.02520578), vec3(-0.69569727, 1.30595522, -0.15446833), vec3(-0.11087861, -0.13586487, 1.17967411));
const mat3 BT2020_TO_709 = mat3(vec3(1.66049100, -0.12455047, -0.01815076), vec3(-0.58764114, 1.13289990, -0.10057890), vec3(-0.07284986, -0.00834942, 1.11872966));
const mat3 BMD_WIDE_GAMUT_TO_709 = mat3(vec3(1.56840470, -0.08635901, -0.05204715), vec3(-0.52267438, 1.34491333, -0.24915526), vec3(-0.04573031, -0.25855432, 1.30120240));

float decode_slog3(float y) {
	if (y >= 171.2102946929 / 1023.0) {
		return pow(10.0, (y * 1023.0 - 420.0) / 261.5) * (0.18 + 0.01) - 0.01;
	}
	return (y * 1023.0 - 95.0) * 0.01125 / (171.2102946929 - 95.0);
}

float decode_logc3(float t) {
	float cut = 0.010591;
	float a = 5.555556;
	float b = 0.052272;
	float c = 0.247190;
	float d = 0.385537;
	float e = 5.367655;
	float f = 0.092809;
	if (t > e * cut + f) {
		return (pow(10.0, (t - d) / c) - b) / a;
	}
	return (t - f) / e;
}

float decode_logc4(float ep) {
	float a = (262144.0 - 16.0) / 117.45;
	float b = (1023.0 - 95.0) / 1023.0;
	float c = 95.0 / 1023.0;
	float s = 0.1135972086105891;
	float t = -0.01805699611991131;
	if (ep >= 0.0) {
		return (exp2(14.0 * (ep - c) / b + 6.0) - 64.0) / a;
	}
	return ep * s + t;
}

float decode_vlog(float v) {
	float b = 0.00873;
	float c = 0.241514;
	float d = 0.598206;
	if (v < 0.181) {
		return (v - 0.125) / 5.6;
	}
	return pow(10.0, (v - d) / c) - b;
}

float decode_flog(float v, float cut2, float a, float b, float c, float d, float e, float f) {
	if (v < cut2) {
		return (v - f) / e;
	}
	return pow(10.0, (v - d) / c) / a - b / a;
}

float decode_nlog(float x) {
	float cut2 = 452.0 / 1023.0;
	float a = 650.0 / 1023.0;
	float b = 0.0075;
	float c = 150.0 / 1023.0;
	float d = 619.0 / 1023.0;
	if (x < cut2) {
		float q = x / a;
		return q * q * q - b;
	}
	return exp((x - d) / c);
}

float decode_apple_log(float p) {
	float r0 = -0.05641088;
	float rt = 0.01;
	float sigma = 47.28711236;
	float beta = 0.00964052;
	float gam = 0.08550479;
	float delta = 0.69336945;
	float pt = sigma * (rt - r0) * (rt - r0);
	if (p >= pt) {
		return exp2((p - delta) / gam) - beta;
	}
	if (p >= 0.0) {
		return sqrt(p / sigma) + r0;
	}
	return r0;
}

float decode_bmd_film5(float y) {
	float ca = 0.08692876065491224;
	float cb = 0.005494072432257808;
	float cc = 0.5300133392291939;
	float cd = 8.283605932402494;
	float ce = 0.09246575342465753;
	float lin_cut = 0.005;
	if (y < cd * lin_cut + ce) {
		return (y - ce) / cd;
	}
	return exp((y - cc) / ca) - cb;
}

float decode_one(float cv, float legal_v) {
	if (source <= 1) {
		return decode_slog3(cv);
	} else if (source == 2) {
		return decode_logc3(cv);
	} else if (source == 3) {
		return decode_logc4(cv);
	} else if (source == 4) {
		return decode_vlog(cv);
	} else if (source == 5) {
		return decode_flog(cv, 0.100537775223865, 0.555556, 0.009468, 0.344676, 0.790453, 8.735631, 0.092864);
	} else if (source == 6) {
		return decode_flog(cv, 0.100686685370811, 5.555556, 0.064829, 0.245281, 0.384316, 8.799461, 0.092864);
	} else if (source == 7) {
		return decode_nlog(cv);
	} else if (source == 8) {
		return decode_apple_log(legal_v);
	}
	return decode_bmd_film5(legal_v);
}

vec3 to_rec709_primaries(vec3 lin) {
	if (source == 0) {
		return S_GAMUT3_CINE_TO_709 * lin;
	} else if (source == 1) {
		return S_GAMUT3_TO_709 * lin;
	} else if (source == 2) {
		return AWG3_TO_709 * lin;
	} else if (source == 3) {
		return AWG4_TO_709 * lin;
	} else if (source == 4) {
		return V_GAMUT_TO_709 * lin;
	} else if (source == 9) {
		return BMD_WIDE_GAMUT_TO_709 * lin;
	}
	return BT2020_TO_709 * lin;
}

float tone_curve(float x) {
	if (tone == 1) {
		float k = 0.6;
		return x < k ? x : k + (1.0 - k) * (1.0 - exp(-(x - k) / (1.0 - k)));
	} else if (tone == 2) {
		float f = x * 0.8;
		return clamp((f * (2.51 * f + 0.03)) / (f * (2.43 * f + 0.59) + 0.14), 0.0, 1.0);
	}
	return min(x, 1.0);
}

float rec709_oetf(float l) {
	l = clamp(l, 0.0, 1.0);
	return l < 0.018 ? l * 4.5 : 1.099 * pow(l, 0.45) - 0.099;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	rgb = clamp(rgb, 0.0, 1.0);
	vec3 cv = full_range ? rgb : (rgb * 876.0 + 64.0) / 1023.0;
	vec3 legal_v = (cv * 1023.0 - 64.0) / 876.0;
	vec3 lin = vec3(decode_one(cv.r, legal_v.r), decode_one(cv.g, legal_v.g), decode_one(cv.b, legal_v.b));
	lin = to_rec709_primaries(lin);
	lin *= exp2(exposure);
	float y = dot(lin, LUMA);
	lin = vec3(y) + (lin - vec3(y)) * saturation;
	lin = max(lin, vec3(0.0));
	vec3 display = vec3(tone_curve(lin.r), tone_curve(lin.g), tone_curve(lin.b));
	vec3 enc = vec3(rec709_oetf(display.r), rec709_oetf(display.g), rec709_oetf(display.b));
	COLOR = vec4(clamp(enc, 0.0, 1.0) * a, a);
}
