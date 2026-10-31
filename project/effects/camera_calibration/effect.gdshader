shader_type canvas_item;
render_mode blend_disabled;

uniform float shadows_tint : hint_range(-100.0, 100.0) = 0.0;
uniform float red_hue : hint_range(-100.0, 100.0) = 10.0;
uniform float red_saturation : hint_range(-100.0, 100.0) = 0.0;
uniform float green_hue : hint_range(-100.0, 100.0) = 0.0;
uniform float green_saturation : hint_range(-100.0, 100.0) = 0.0;
uniform float blue_hue : hint_range(-100.0, 100.0) = -40.0;
uniform float blue_saturation : hint_range(-100.0, 100.0) = 30.0;

const vec3 LUMA_LIN = vec3(0.2126, 0.7152, 0.0722);
const float HUE_RANGE = 0.5235988;
const float SAT_RANGE = 0.47;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_srgb(vec3 c) {
	vec3 p = max(c, vec3(0.0));
	return mix(p * 12.92, 1.055 * pow(p, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), p));
}

float cbrt(float x) {
	return sign(x) * pow(abs(x), 1.0 / 3.0);
}

vec3 lin_to_oklab(vec3 c) {
	float l = cbrt(0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b);
	float m = cbrt(0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b);
	float s = cbrt(0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b);
	return vec3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s, 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s, 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s);
}

vec3 oklab_to_lin(vec3 c) {
	float l = c.x + 0.3963377774 * c.y + 0.2158037573 * c.z;
	float m = c.x - 0.1055613458 * c.y - 0.0638541728 * c.z;
	float s = c.x - 0.0894841775 * c.y - 1.2914855480 * c.z;
	l = l * l * l;
	m = m * m * m;
	s = s * s * s;
	return vec3(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s, -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s, -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s);
}

vec3 moved_primary(vec3 p, float hue, float sat) {
	vec3 lab = lin_to_oklab(p);
	float ang = clamp(hue, -100.0, 100.0) / 100.0 * HUE_RANGE;
	float k = exp(clamp(sat, -100.0, 100.0) / 100.0 * SAT_RANGE);
	float cs = cos(ang);
	float sn = sin(ang);
	vec2 ab = vec2(lab.y * cs - lab.z * sn, lab.y * sn + lab.z * cs) * k;
	return oklab_to_lin(vec3(lab.x, ab));
}

mat3 calibration() {
	vec3 r = moved_primary(vec3(1.0, 0.0, 0.0), red_hue, red_saturation);
	vec3 g = moved_primary(vec3(0.0, 1.0, 0.0), green_hue, green_saturation);
	vec3 b = moved_primary(vec3(0.0, 0.0, 1.0), blue_hue, blue_saturation);
	mat3 m = mat3(r, g, b);
	vec3 k = inverse(m) * vec3(1.0);
	return mat3(r * k.x, g * k.y, b * k.z);
}

vec3 soft_floor(vec3 c) {
	vec3 k = vec3(0.003);
	return mix(k * exp((c - k) / k), c, step(k, c));
}

vec3 into_gamut(vec3 c) {
	float y = dot(c, LUMA_LIN);
	if (y <= 0.0) {
		return vec3(0.0);
	}
	float lo = min(c.r, min(c.g, c.b));
	vec3 outc = c;
	if (lo < 0.0) {
		float t = y / (y - lo);
		outc = vec3(y) + (c - vec3(y)) * mix(1.0, t, 0.35);
	}
	outc = soft_floor(outc);
	float hi = max(outc.r, max(outc.g, outc.b));
	if (hi > 1.0) {
		float yc = min(dot(outc, LUMA_LIN), 1.0);
		vec3 d = outc - vec3(yc);
		float dmax = max(d.r, max(d.g, d.b));
		if (dmax > 0.000001) {
			outc = vec3(yc) + d * mix(1.0, clamp((1.0 - yc) / dmax, 0.0, 1.0), 0.35);
		}
	}
	return clamp(outc, 0.0, 1.0);
}

vec3 tint_shadows(vec3 lin, float v) {
	float t = clamp(shadows_tint, -100.0, 100.0) / 100.0;
	float w = 1.0 - smoothstep(0.0, 0.5, v);
	w *= w;
	float a = 0.28 * t * w;
	vec3 gains = vec3(1.0 + a, 1.0 - a, 1.0 + a);
	gains /= dot(gains, LUMA_LIN);
	return lin * gains;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
	vec3 lin = to_linear(rgb);
	float v = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 moved = into_gamut(tint_shadows(calibration() * lin, v));
	vec3 outc = to_srgb(moved);
	COLOR = vec4(clamp(outc, 0.0, 1.0) * c.a, c.a);
}
