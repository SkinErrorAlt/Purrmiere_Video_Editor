shader_type canvas_item;
render_mode blend_disabled;

uniform float stroke_size : hint_range(4.0, 80.0) = 26.0;
uniform float stroke_detail : hint_range(1.0, 3.0) = 3.0;
uniform float softness : hint_range(0.0, 10.0) = 0.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

const float ASPECT = 2.4;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 seed_offset(int s) {
	float f = float(s);
	return vec2(mod(f * 12.9898, 997.0), mod(f * 78.233, 991.0));
}

vec3 unpremul(vec4 c) {
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
}

float weave(vec2 p, float period) {
	vec2 q = p / period;
	vec2 cell = floor(q);
	vec2 f = fract(q);
	float hor = sin(f.y * 3.14159) * (0.55 + 0.45 * sin(f.x * 3.14159));
	float ver = sin(f.x * 3.14159) * (0.55 + 0.45 * sin(f.y * 3.14159));
	return mod(cell.x + cell.y, 2.0) < 1.0 ? hor : ver;
}

#define SLAB(pt, ax) ((unpremul(texture(TEXTURE, (pt) * k)) * 2.0 + unpremul(texture(TEXTURE, ((pt) + (ax) * 0.55) * k)) + unpremul(texture(TEXTURE, ((pt) - (ax) * 0.55) * k))) * 0.25)

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec2 so = seed_offset(seed);
	vec2 pix = UV * dims / ps;
	float size = max(stroke_size, 4.0);
	vec2 p = pix / size;
	vec2 k = size * ps / dims;
	vec2 base = floor(p);
	float d1 = 99.0;
	float d2 = 99.0;
	vec2 pt1 = base + 0.5;
	vec2 ax1 = vec2(1.0, 0.0);
	vec2 pt2 = base + 0.5;
	vec2 ax2 = vec2(1.0, 0.0);
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 cell = base + vec2(float(x), float(y));
			vec2 h = hash22(cell + so);
			vec2 pt = cell + 0.1 + h * 0.8;
			float ang = hash12(cell.yx + so * 1.7) * 3.14159;
			vec2 ax = vec2(cos(ang), sin(ang));
			vec2 q = p - pt;
			float d = length(vec2(dot(q, ax) / ASPECT, dot(q, vec2(-ax.y, ax.x)))) * (0.8 + 0.4 * h.y);
			if (d < d1) {
				d2 = d1;
				pt2 = pt1;
				ax2 = ax1;
				d1 = d;
				pt1 = pt;
				ax1 = ax;
			} else if (d < d2) {
				d2 = d;
				pt2 = pt;
				ax2 = ax;
			}
		}
	}
	vec3 c1 = SLAB(pt1, ax1);
	vec3 local = unpremul(c);
	vec3 col = mix(c1, local, (clamp(stroke_detail, 1.0, 3.0) - 1.0) * 0.5 * 0.3);
	float gap = d2 - d1;
	if (softness > 0.0) {
		vec3 c2 = SLAB(pt2, ax2);
		float w = smoothstep(0.0, softness * 0.035, gap);
		col = mix((col + c2) * 0.5, col, w);
	}
	vec2 q1 = p - pt1;
	float u1 = dot(q1, ax1);
	float v1 = dot(q1, vec2(-ax1.y, ax1.x));
	float ridge = 1.0 - smoothstep(0.0, 1.4 / size, gap);
	float shade = ridge * (u1 > 0.0 ? 0.07 : -0.12);
	float drag = value_noise(vec2(u1 * 3.0, v1 * size / 1.6) + so) - 0.5;
	float canvas = weave(pix, 3.2) - 0.5;
	col *= 1.0 + shade + drag * 0.07 + canvas * 0.06;
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}
