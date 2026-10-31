shader_type canvas_item;
render_mode blend_disabled;

uniform int source : hint_range(0, 1) = 0;
uniform float peak : hint_range(100.0, 10000.0) = 1000.0;
uniform float exposure : hint_range(-3.0, 3.0) = 0.0;
uniform int tone : hint_range(0, 2) = 0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform bool convert_gamut = true;

const vec3 LUMA709 = vec3(0.2126, 0.7152, 0.0722);
const vec3 LUMA2020 = vec3(0.2627, 0.6780, 0.0593);
const float SDR_WHITE = 203.0;

vec3 pq_to_nits(vec3 e) {
	float m1 = 0.1593017578125;
	float m2 = 78.84375;
	float c1 = 0.8359375;
	float c2 = 18.8515625;
	float c3 = 18.6875;
	vec3 p = pow(clamp(e, 0.0, 1.0), vec3(1.0 / m2));
	vec3 num = max(p - vec3(c1), vec3(0.0));
	vec3 den = max(vec3(c2) - c3 * p, vec3(0.0001));
	return pow(num / den, vec3(1.0 / m1)) * 10000.0;
}

vec3 hlg_to_nits(vec3 e) {
	float a = 0.17883277;
	float b = 0.28466892;
	float c = 0.55991073;
	vec3 x = clamp(e, 0.0, 1.0);
	vec3 lo = x * x / 3.0;
	vec3 hi = (exp((x - vec3(c)) / a) + vec3(b)) / 12.0;
	vec3 scene = mix(lo, hi, step(vec3(0.5), x));
	float ys = max(dot(scene, LUMA2020), 0.000001);
	return scene * pow(ys, 0.2) * 1000.0;
}

vec3 to_709(vec3 c) {
	return vec3(
		dot(c, vec3(1.6605, -0.5876, -0.0728)),
		dot(c, vec3(-0.1246, 1.1329, -0.0083)),
		dot(c, vec3(-0.0182, -0.1006, 1.1187)));
}

float nits_to_pq(float n) {
	float m1 = 0.1593017578125;
	float m2 = 78.84375;
	float c1 = 0.8359375;
	float c2 = 18.8515625;
	float c3 = 18.6875;
	float y = pow(clamp(n / 10000.0, 0.0, 1.0), m1);
	return pow((c1 + c2 * y) / (1.0 + c3 * y), m2);
}

float pq_one_to_nits(float e) {
	return pq_to_nits(vec3(e)).x;
}

vec3 tone_map(vec3 c, float peak_nits) {
	if (tone == 2) {
		return clamp(c, 0.0, 1.0);
	}
	float m = max(c.r, max(c.g, c.b));
	if (m <= 0.0) {
		return vec3(0.0);
	}
	float mapped;
	if (tone == 1) {
		float x = m * 0.6;
		mapped = clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
	} else {
		float src_peak = max(peak_nits, SDR_WHITE * 1.01);
		float pq_peak = nits_to_pq(src_peak);
		float e1 = clamp(nits_to_pq(m * SDR_WHITE) / pq_peak, 0.0, 1.0);
		float max_lum = nits_to_pq(SDR_WHITE) / pq_peak;
		float ks = 1.5 * max_lum - 0.5;
		float e2 = e1;
		if (e1 > ks) {
			float t = (e1 - ks) / max(1.0 - ks, 0.0001);
			float t2 = t * t;
			float t3 = t2 * t;
			e2 = (2.0 * t3 - 3.0 * t2 + 1.0) * ks + (t3 - 2.0 * t2 + t) * (1.0 - ks) + (-2.0 * t3 + 3.0 * t2) * max_lum;
		}
		mapped = clamp(pq_one_to_nits(e2 * pq_peak) / SDR_WHITE, 0.0, 1.0);
	}
	return c * (mapped / m);
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float a = src.a;
	vec3 e = a > 0.0001 ? clamp(src.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 nits = source == 1 ? hlg_to_nits(e) : pq_to_nits(e);
	vec3 lin = nits / SDR_WHITE * exp2(clamp(exposure, -3.0, 3.0));
	if (convert_gamut) {
		lin = max(to_709(lin), vec3(0.0));
	}
	float l = dot(lin, LUMA709);
	lin = max(vec3(l) + (lin - vec3(l)) * clamp(saturation, 0.0, 2.0), vec3(0.0));
	lin = tone_map(lin, clamp(peak, 100.0, 10000.0) * exp2(clamp(exposure, -3.0, 3.0)));
	vec3 outc = pow(clamp(lin, 0.0, 1.0), vec3(1.0 / 2.4));
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
