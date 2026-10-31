shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D near_tex : filter_linear, repeat_disable;
uniform sampler2D wide_tex : filter_linear, repeat_disable;
uniform float strength : hint_range(0.0, 100.0) = 80.0;
uniform float sun_angle : hint_range(-180.0, 180.0) = 70.0;
uniform float sky_darkening : hint_range(0.0, 100.0) = 70.0;
uniform float glare_cut : hint_range(0.0, 100.0) = 60.0;
uniform float foliage : hint_range(0.0, 100.0) = 50.0;
uniform float keep_skin : hint_range(0.0, 100.0) = 80.0;

const vec3 LUMA_LIN = vec3(0.2126, 0.7152, 0.0722);
const float HALF_FOV = 0.6109;
const float SUN_HEIGHT = 0.5236;

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

vec3 lab_in_gamut(vec3 lab) {
	vec3 lin = oklab_to_lin(lab);
	if (inside(lin)) {
		return lin;
	}
	float lo = 0.0;
	float hi = 1.0;
	for (int i = 0; i < 10; i++) {
		float mid = 0.5 * (lo + hi);
		if (inside(oklab_to_lin(vec3(lab.x, lab.yz * mid)))) {
			lo = mid;
		} else {
			hi = mid;
		}
	}
	return clamp(oklab_to_lin(vec3(lab.x, lab.yz * lo)), 0.0, 1.0);
}

vec4 cubic_sample(sampler2D tex, vec2 uv) {
	vec2 size = vec2(textureSize(tex, 0));
	vec2 p = uv * size - 0.5;
	vec2 f = fract(p);
	vec2 i = floor(p);
	vec2 f2 = f * f;
	vec2 f3 = f2 * f;
	vec2 w0 = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0;
	vec2 w1 = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
	vec2 w2 = (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0;
	vec2 w3 = f3 / 6.0;
	vec2 g0 = w0 + w1;
	vec2 g1 = w2 + w3;
	vec2 h0 = (i - 0.5 + w1 / g0) / size;
	vec2 h1 = (i + 1.5 + w3 / g1) / size;
	vec4 a = texture(tex, vec2(h0.x, h0.y));
	vec4 b = texture(tex, vec2(h1.x, h0.y));
	vec4 c = texture(tex, vec2(h0.x, h1.y));
	vec4 d = texture(tex, vec2(h1.x, h1.y));
	return g0.y * (g0.x * a + g1.x * b) + g1.y * (g0.x * c + g1.x * d);
}

float hue_window(vec2 ab, float centre, float half_width, float soft) {
	float h = atan(ab.y, ab.x);
	float d = abs(mod(h - centre + PI, 2.0 * PI) - PI);
	return 1.0 - smoothstep(half_width, half_width + soft, d);
}

float sky_mask(vec3 lab) {
	float c = length(lab.yz);
	float hue = hue_window(lab.yz, radians(245.0), radians(32.0), radians(22.0));
	return hue * smoothstep(0.025, 0.1, c) * smoothstep(0.3, 0.55, lab.x);
}

float skin_mask(vec3 lab) {
	float c = length(lab.yz);
	float hue = hue_window(lab.yz, radians(58.0), radians(20.0), radians(16.0));
	return hue * smoothstep(0.025, 0.045, c) * (1.0 - smoothstep(0.13, 0.19, c)) * smoothstep(0.38, 0.5, lab.x);
}

float sky_near(vec3 lab) {
	float c = length(lab.yz);
	float hue = hue_window(lab.yz, radians(245.0), radians(40.0), radians(25.0));
	return hue * smoothstep(0.004, 0.02, c) * smoothstep(0.25, 0.45, lab.x);
}

float foliage_mask(vec3 lab) {
	float c = length(lab.yz);
	float hue = hue_window(lab.yz, radians(128.0), radians(26.0), radians(22.0));
	return hue * smoothstep(0.015, 0.05, c);
}

float polarisation(vec2 uv, vec2 frame) {
	float aspect = frame.y / max(frame.x, 1.0);
	float tx = tan(HALF_FOV);
	vec3 view = normalize(vec3((uv.x * 2.0 - 1.0) * tx, (1.0 - uv.y * 2.0) * tx * aspect, 1.0));
	float az = radians(sun_angle);
	vec3 sun = vec3(sin(az) * cos(SUN_HEIGHT), sin(SUN_HEIGHT), cos(az) * cos(SUN_HEIGHT));
	float cg = dot(view, sun);
	return (1.0 - cg * cg) / (1.0 + cg * cg);
}

void fragment() {
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec4 nb4 = cubic_sample(wide_tex, UV);
	vec3 nb = nb4.a > 0.0001 ? clamp(nb4.rgb / nb4.a, 0.0, 1.0) : rgb;
	float s = clamp(strength, 0.0, 100.0) / 100.0;
	vec3 lin = to_linear(rgb);
	vec3 nb_lin = to_linear(nb);
	vec3 lab = lin_to_oklab(lin);
	vec3 nb_lab = lin_to_oklab(nb_lin);
	float skin = skin_mask(lab) * clamp(keep_skin, 0.0, 100.0) / 100.0;
	float keep = 1.0 - skin;
	float sky_nb = sky_near(nb_lab);
	float spec_gate = (1.0 - sky_nb) * keep;
	float own_low = min(lin.r, min(lin.g, lin.b));
	float nb_low = min(nb_lin.r, min(nb_lin.g, nb_lin.b));
	float own_c = length(lab.yz);
	float nb_c = length(nb_lab.yz);
	float whiter = smoothstep(-0.01, 0.03, nb_c - own_c * 0.8);
	vec2 step_uv = 2.0 / max(vec2(textureSize(near_tex, 0)), vec2(1.0));
	float ring = 0.0;
	for (int k = 0; k < 8; k++) {
		float ang = float(k) * 0.7853982;
		vec4 o = texture(near_tex, UV + vec2(cos(ang), sin(ang)) * step_uv);
		vec3 ol = to_linear(o.a > 0.0001 ? clamp(o.rgb / o.a, 0.0, 1.0) : rgb);
		ring = max(ring, min(ol.r, min(ol.g, ol.b)));
	}
	float sheen = max(own_low - max(ring, nb_low), 0.0) * whiter * spec_gate;
	float cut = s * clamp(glare_cut, 0.0, 100.0) / 100.0;
	lin = max(lin - vec3(sheen * cut * 0.9), vec3(0.0));
	float veil = nb_low * 0.12 * cut * (1.0 - sky_nb) * keep;
	lin = max((lin - vec3(veil)) / max(1.0 - veil, 0.2), vec3(0.0));
	lab = lin_to_oklab(lin);
	float p = polarisation(UV, vec2(textureSize(effect_tex, 0)));
	float sky = sky_mask(lab) * keep;
	float dark = s * clamp(sky_darkening, 0.0, 100.0) / 100.0 * p * sky;
	lab.x *= 1.0 - 0.36 * dark;
	lab.yz *= 1.0 + 0.5 * dark;
	float leaf = foliage_mask(lab) * keep * s * clamp(foliage, 0.0, 100.0) / 100.0;
	lab.yz *= 1.0 + 0.5 * leaf;
	lab.x *= 1.0 - 0.07 * leaf;
	vec3 outc = to_srgb(lab_in_gamut(lab));
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
