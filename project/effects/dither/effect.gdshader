shader_type canvas_item;
render_mode blend_disabled;

uniform int pattern : hint_range(0, 3) = 1;
uniform int levels : hint_range(2, 32) = 4;
uniform bool monochrome = false;
uniform float pixel_size : hint_range(1.0, 32.0) = 2.0;
uniform float contrast : hint_range(0.0, 3.0) = 1.0;
uniform vec4 dark_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 light_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float bayer(ivec2 p, int bits) {
	int v = 0;
	for (int i = 0; i < 3; i++) {
		if (i >= bits) {
			break;
		}
		int xb = (p.x >> i) & 1;
		int yb = (p.y >> i) & 1;
		int sh = 2 * (bits - 1 - i);
		v = v | ((((xb ^ yb) << 1) | yb) << sh);
	}
	float n = float(1 << (2 * bits));
	return (float(v) + 0.5) / n;
}

float gradient_noise(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

float quantise(float v, float n, float t) {
	return clamp(floor(v * n + t), 0.0, n) / n;
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float ps = max(pixel_size * px_scale, 1.0);
	vec2 cell = floor(UV * size / ps);
	vec2 cuv = clamp((cell + 0.5) * ps / size, vec2(0.0), vec2(1.0));
	vec4 c = texture(TEXTURE, cuv);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	rgb = clamp((rgb - 0.5) * contrast + 0.5, 0.0, 1.0);
	float t;
	ivec2 ip = ivec2(mod(cell, 8.0));
	if (pattern == 0) {
		t = bayer(ip, 1);
	} else if (pattern == 1) {
		t = bayer(ip, 2);
	} else if (pattern == 2) {
		t = bayer(ip, 3);
	} else {
		t = gradient_noise(cell);
	}
	float n = float(max(levels, 2) - 1);
	if (monochrome) {
		float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
		float q = quantise(luma, n, t);
		rgb = mix(dark_colour.rgb, light_colour.rgb, q);
	} else {
		rgb = vec3(quantise(rgb.r, n, t), quantise(rgb.g, n, t), quantise(rgb.b, n, t));
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
