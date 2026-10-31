shader_type canvas_item;
render_mode blend_disabled;

uniform int dot_type : hint_range(0, 9) = 0;
uniform int colour_mode : hint_range(0, 1) = 0;
uniform vec4 ink : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 paper : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float grain_size : hint_range(1.0, 8.0) = 1.0;
uniform bool moving = false;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float time = 0.0;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float flat_noise(float n) {
	float c = n < 0.5 ? 2.0 * n * n : 1.0 - 2.0 * (1.0 - n) * (1.0 - n);
	return mix(n, c, 0.75);
}

float threshold(vec2 p, vec2 off) {
	vec2 q = p + off;
	float fine = h12(floor(q));
	if (dot_type == 0) {
		return fine;
	}
	if (dot_type == 1) {
		return flat_noise(vn(q / 1.7)) * 0.8 + fine * 0.2;
	}
	if (dot_type == 2) {
		return flat_noise(vn(q / 1.2) * 0.6 + vn(q / 3.5 + 9.0) * 0.4) * 0.6 + fine * 0.4;
	}
	if (dot_type == 3) {
		return flat_noise(vn(q / 3.2)) * 0.85 + fine * 0.15;
	}
	if (dot_type >= 4 && dot_type <= 6) {
		float len = dot_type == 4 ? 3.0 : (dot_type == 5 ? 8.0 : 20.0);
		float row = floor(q.y);
		return flat_noise(vn(vec2(q.x / len, row * 1.7))) * 0.9 + fine * 0.1;
	}
	float len = dot_type == 7 ? 4.0 : (dot_type == 8 ? 8.0 : 16.0);
	vec2 cell = floor(q / len);
	float an = (h12(cell + 7.0) - 0.5) * 1.6 + 0.785;
	float cs = cos(an);
	float sn = sin(an);
	vec2 r = vec2(cs * q.x + sn * q.y, -sn * q.x + cs * q.y);
	return flat_noise(vn(vec2(r.x / len, floor(r.y / 1.2) * 1.3 + cell.x * 3.1 + cell.y * 5.7))) * 0.9 + fine * 0.1;
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float fs = float(seed);
	if (moving) {
		fs += floor(max(time, 0.0) * 24.0) * 7.0;
	}
	vec2 so = vec2(mod(fs * 12.9898, 997.0), mod(fs * 78.233, 991.0));
	vec2 P = UV * dims / ps / max(grain_size, 0.5) + so;
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 col;
	if (colour_mode == 1) {
		float l = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
		col = l > threshold(P, vec2(0.0)) ? paper.rgb : ink.rgb;
	} else {
		float r = rgb.r > threshold(P, vec2(0.0)) ? paper.r : ink.r;
		float g = rgb.g > threshold(P, vec2(37.0, 113.0)) ? paper.g : ink.g;
		float b = rgb.b > threshold(P, vec2(171.0, 59.0)) ? paper.b : ink.b;
		col = vec3(r, g, b);
	}
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}
