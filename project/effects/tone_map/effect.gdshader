shader_type canvas_item;
render_mode blend_disabled;

uniform float exposure : hint_range(-4.0, 4.0) = 0.0;
uniform int operator : hint_range(0, 3) = 0;
uniform float knee : hint_range(0.0, 1.0) = 0.5;
uniform float white_point : hint_range(1.0, 16.0) = 2.0;
uniform bool preserve_colour = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float rec709_decode(float v) {
	v = clamp(v, 0.0, 1.0);
	return v < 0.081 ? v / 4.5 : pow((v + 0.099) / 1.099, 1.0 / 0.45);
}

float rec709_encode(float l) {
	l = clamp(l, 0.0, 1.0);
	return l < 0.018 ? l * 4.5 : 1.099 * pow(l, 0.45) - 0.099;
}

float hable(float x) {
	float ha = 0.15;
	float hb = 0.50;
	float hc = 0.10;
	float hd = 0.20;
	float he = 0.02;
	float hf = 0.30;
	return ((x * (ha * x + hc * hb) + hd * he) / (x * (ha * x + hb) + hd * hf)) - he / hf;
}

float aces_fit(float x) {
	return (x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14);
}

float curve(float x, float k, float w) {
	x = max(x, 0.0);
	if (operator == 1) {
		if (x <= k) {
			return x;
		}
		float span = max(1.0 - k, 0.0001);
		float u = (x - k) / span;
		float wu = max((w - k) / span, 1.0);
		float r = u * (1.0 + u / (wu * wu)) / (1.0 + u);
		return min(k + span * r, 1.0);
	} else if (operator == 2) {
		return min(aces_fit(x * 0.8) / max(aces_fit(w * 0.8), 0.0001), 1.0);
	} else if (operator == 3) {
		return min(hable(x * 2.0) / max(hable(w * 2.0), 0.0001), 1.0);
	}
	if (x <= k) {
		return x;
	}
	float span = max(1.0 - k, 0.0001);
	float s = max((w - k) / span, 1.0);
	float u = min((x - k) / max(w - k, 0.0001), 1.0);
	float g = s * u / (1.0 + (s - 1.0) * u);
	return min(k + span * g, 1.0);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 lin = vec3(rec709_decode(rgb.r), rec709_decode(rgb.g), rec709_decode(rgb.b));
	lin *= exp2(exposure);
	float k = clamp(knee, 0.0, 0.99);
	float w = max(white_point, 1.0);
	vec3 mapped;
	if (preserve_colour) {
		float y = dot(lin, LUMA);
		float ym = curve(y, k, w);
		mapped = y > 0.00001 ? lin * (ym / y) : vec3(0.0);
		float peak = max(mapped.r, max(mapped.g, mapped.b));
		if (peak > 1.0) {
			float t = (peak - 1.0) / max(peak - ym, 0.0001);
			mapped = mix(mapped, vec3(ym), clamp(t, 0.0, 1.0));
		}
	} else {
		mapped = vec3(curve(lin.r, k, w), curve(lin.g, k, w), curve(lin.b, k, w));
	}
	vec3 enc = vec3(rec709_encode(mapped.r), rec709_encode(mapped.g), rec709_encode(mapped.b));
	COLOR = vec4(clamp(enc, 0.0, 1.0) * a, a);
}
