shader_type canvas_item;
render_mode blend_disabled;

uniform int measure : hint_range(0, 1) = 1;

const vec3 LUMA_LIN = vec3(0.2126, 0.7152, 0.0722);

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

bool inside(vec3 c) {
	return all(greaterThanEqual(c, vec3(-0.00002))) && all(lessThanEqual(c, vec3(1.00002)));
}

float fit_chroma(float l, vec2 dir, float want) {
	if (inside(oklab_to_lin(vec3(l, dir * want)))) {
		return want;
	}
	float lo = 0.0;
	float hi = want;
	for (int i = 0; i < 14; i++) {
		float mid = 0.5 * (lo + hi);
		if (inside(oklab_to_lin(vec3(l, dir * mid)))) {
			lo = mid;
		} else {
			hi = mid;
		}
	}
	return lo;
}

float lstar(float y) {
	return y > 0.008856 ? 116.0 * pow(y, 1.0 / 3.0) - 16.0 : 903.3 * y;
}

float lstar_inverse(float l) {
	return l > 8.0 ? pow((l + 16.0) / 116.0, 3.0) : l / 903.3;
}

vec3 invert_value(vec3 rgb) {
	float v = max(rgb.r, max(rgb.g, rgb.b));
	if (v < 0.00001) {
		return vec3(1.0);
	}
	return rgb * ((1.0 - v) / v);
}

vec3 invert_perceptual(vec3 rgb) {
	vec3 lin = to_linear(rgb);
	float y = clamp(dot(lin, LUMA_LIN), 0.0, 1.0);
	float target = clamp(lstar_inverse(100.0 - lstar(y)), 0.0, 1.0);
	vec3 lab = lin_to_oklab(lin);
	float chroma = length(lab.yz);
	vec2 dir = chroma > 0.000001 ? lab.yz / chroma : vec2(0.0);
	float l = pow(target, 1.0 / 3.0);
	vec3 outc = vec3(target);
	for (int i = 0; i < 4; i++) {
		float c = fit_chroma(l, dir, chroma);
		outc = oklab_to_lin(vec3(l, dir * c));
		float now = dot(outc, LUMA_LIN);
		if (now > 0.0000001 && target > 0.0000001) {
			l = clamp(l * pow(target / now, 1.0 / 3.0), 0.0, 1.0);
		}
	}
	float c_last = fit_chroma(l, dir, chroma);
	outc = oklab_to_lin(vec3(l, dir * c_last));
	return to_srgb(clamp(outc, 0.0, 1.0));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
	vec3 outc = measure == 0 ? invert_value(rgb) : invert_perceptual(rgb);
	COLOR = vec4(clamp(outc, 0.0, 1.0) * c.a, c.a);
}
