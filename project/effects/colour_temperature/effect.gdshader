shader_type canvas_item;
render_mode blend_disabled;

uniform float from_k : hint_range(1700.0, 15000.0) = 5400.0;
uniform float from_tint : hint_range(-1.0, 1.0) = 0.0;
uniform float to_k : hint_range(1700.0, 15000.0) = 6500.0;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform bool keep_brightness = true;

vec3 to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_display(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec2 planck_xy(float t) {
	float x;
	if (t < 4000.0) {
		x = -0.2661239e9 / (t * t * t) - 0.2343589e6 / (t * t) + 0.8776956e3 / t + 0.179910;
	} else {
		x = -3.0258469e9 / (t * t * t) + 2.1070379e6 / (t * t) + 0.2226347e3 / t + 0.240390;
	}
	float y;
	if (t < 2222.0) {
		y = -1.1063814 * x * x * x - 1.34811020 * x * x + 2.18555832 * x - 0.20219683;
	} else if (t < 4000.0) {
		y = -0.9549476 * x * x * x - 1.37418593 * x * x + 2.09137015 * x - 0.16748867;
	} else {
		y = 3.0817580 * x * x * x - 5.87338670 * x * x + 3.75112997 * x - 0.37001483;
	}
	return vec2(x, y);
}

vec2 daylight_xy(float t) {
	float x;
	if (t <= 7000.0) {
		x = -4.6070e9 / (t * t * t) + 2.9678e6 / (t * t) + 0.09911e3 / t + 0.244063;
	} else {
		x = -2.0064e9 / (t * t * t) + 1.9018e6 / (t * t) + 0.24748e3 / t + 0.237040;
	}
	return vec2(x, -3.0 * x * x + 2.87 * x - 0.275);
}

vec2 white_xy(float kelvin) {
	float t = clamp(kelvin, 1700.0, 15000.0);
	vec2 p = planck_xy(max(t, 1667.0));
	vec2 d = daylight_xy(max(t, 4000.0));
	return mix(p, d, smoothstep(3500.0, 4500.0, t));
}

vec2 tinted_xy(float kelvin, float tint) {
	vec2 w = white_xy(kelvin);
	vec2 a = white_xy(kelvin - 50.0);
	vec2 b = white_xy(kelvin + 50.0);
	vec2 along = normalize(b - a + vec2(0.000001));
	vec2 toward_green = vec2(-along.y, along.x);
	if (toward_green.y < 0.0) {
		toward_green = -toward_green;
	}
	return w - toward_green * tint * 0.02;
}

vec3 xyz_of(vec2 xy) {
	return vec3(xy.x / xy.y, 1.0, (1.0 - xy.x - xy.y) / xy.y);
}

vec3 bradford(vec3 v) {
	return vec3(dot(v, vec3(0.8951, 0.2664, -0.1614)), dot(v, vec3(-0.7502, 1.7135, 0.0367)), dot(v, vec3(0.0389, -0.0685, 1.0296)));
}

vec3 bradford_back(vec3 v) {
	return vec3(dot(v, vec3(0.9869929, -0.1470543, 0.1599627)), dot(v, vec3(0.4323053, 0.5183603, 0.0492912)), dot(v, vec3(-0.0085287, 0.0400428, 0.9684867)));
}

vec3 rgb_to_xyz(vec3 c) {
	return vec3(dot(c, vec3(0.4124564, 0.3575761, 0.1804375)), dot(c, vec3(0.2126729, 0.7151522, 0.0721750)), dot(c, vec3(0.0193339, 0.1191920, 0.9503041)));
}

vec3 xyz_to_rgb(vec3 c) {
	return vec3(dot(c, vec3(3.2404542, -1.5371385, -0.4985314)), dot(c, vec3(-0.9692660, 1.8760108, 0.0415560)), dot(c, vec3(0.0556434, -0.2040259, 1.0572252)));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 src_lms = bradford(xyz_of(tinted_xy(from_k, from_tint)));
	vec3 dst_lms = bradford(xyz_of(white_xy(to_k)));
	vec3 lin = to_linear(rgb);
	vec3 xyz = rgb_to_xyz(lin);
	vec3 adapted = bradford_back(bradford(xyz) * dst_lms / max(src_lms, vec3(0.0001)));
	vec3 out_lin = max(xyz_to_rgb(adapted), vec3(0.0));
	if (keep_brightness) {
		float before = xyz.y;
		float after = max(dot(out_lin, vec3(0.2126729, 0.7151522, 0.0721750)), 0.000001);
		out_lin *= before / after;
	}
	vec3 outc = mix(rgb, to_display(out_lin), amount);
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
