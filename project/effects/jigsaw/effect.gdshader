shader_type canvas_item;
render_mode blend_disabled;

uniform int columns : hint_range(2, 40) = 6;
uniform int rows : hint_range(2, 40) = 4;
uniform int style : hint_range(0, 1) = 0;
uniform float knob : hint_range(0.1, 0.3) = 0.2;
uniform float bevel : hint_range(0.0, 40.0) = 6.0;
uniform float highlight : hint_range(0.0, 1.0) = 0.6;
uniform float line : hint_range(0.0, 10.0) = 1.5;
uniform float line_dark : hint_range(0.0, 1.0) = 0.7;
uniform float light_angle : hint_range(0.0, 360.0) = 225.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float hash3(float a, float b, float c) {
	vec3 p3 = fract(vec3(a * 0.1031 + float(seed) * 0.0713, b * 0.1030 + 0.37, c * 0.0973 + 0.11));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float edge_dist(float u, float v, float v0, float v1, float vm, float s, float r) {
	float h;
	float d;
	if (style == 1) {
		float depth = 1.5 * r;
		h = 0.75 * r;
		float far_u = s * depth;
		d = length(vec2(u - far_u, v - clamp(v, vm - h, vm + h)));
		float uu = clamp(u, min(0.0, far_u), max(0.0, far_u));
		d = min(d, length(vec2(u - uu, v - (vm - h))));
		d = min(d, length(vec2(u - uu, v - (vm + h))));
	} else {
		float cc = 0.85 * r;
		h = sqrt(max(r * r - cc * cc, 0.0));
		vec2 q = vec2(u - s * cc, v - vm);
		float len = length(q);
		d = 1.0e6;
		if (len > 0.0001 && s * q.x / len >= -cc / r) {
			d = abs(len - r);
		}
	}
	float a_hi = max(vm - h, v0);
	float b_lo = min(vm + h, v1);
	if (a_hi > v0) {
		d = min(d, length(vec2(u, v - clamp(v, v0, a_hi))));
	}
	if (b_lo < v1) {
		d = min(d, length(vec2(u, v - clamp(v, b_lo, v1))));
	}
	return d;
}

float cut_dist(vec2 p, ivec2 cell, vec2 piece, vec2 sz) {
	float r = clamp(knob, 0.1, 0.3) * min(piece.x, piece.y);
	float d = min(min(p.x, p.y), min(sz.x - p.x, sz.y - p.y));
	for (int k = 0; k < 2; k++) {
		int ci = cell.x + k;
		if (ci > 0 && ci < columns) {
			float x = float(ci) * piece.x;
			float s = hash3(float(ci), float(cell.y), 1.0) < 0.5 ? -1.0 : 1.0;
			float vm = (float(cell.y) + 0.5) * piece.y + (hash3(float(ci), float(cell.y), 2.0) - 0.5) * 0.1 * piece.y;
			d = min(d, edge_dist(p.x - x, p.y, float(cell.y) * piece.y, float(cell.y + 1) * piece.y, vm, s, r));
		}
		int cj = cell.y + k;
		if (cj > 0 && cj < rows) {
			float y = float(cj) * piece.y;
			float s = hash3(float(cell.x), float(cj), 3.0) < 0.5 ? -1.0 : 1.0;
			float vm = (float(cell.x) + 0.5) * piece.x + (hash3(float(cell.x), float(cj), 4.0) - 0.5) * 0.1 * piece.x;
			d = min(d, edge_dist(p.y - y, p.x, float(cell.x) * piece.x, float(cell.x + 1) * piece.x, vm, s, r));
		}
	}
	return d;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 piece = sz / vec2(float(max(columns, 1)), float(max(rows, 1)));
	vec2 p = UV * sz;
	ivec2 cell = ivec2(clamp(floor(p / piece), vec2(0.0), vec2(float(columns - 1), float(rows - 1))));
	float d = cut_dist(p, cell, piece, sz);
	float e = 0.5;
	vec2 grad = vec2(cut_dist(p + vec2(e, 0.0), cell, piece, sz) - cut_dist(p - vec2(e, 0.0), cell, piece, sz), cut_dist(p + vec2(0.0, e), cell, piece, sz) - cut_dist(p - vec2(0.0, e), cell, piece, sz));
	vec2 n_out = length(grad) > 0.0001 ? -normalize(grad) : vec2(0.0);
	float rad = radians(light_angle);
	vec2 light = vec2(cos(rad), sin(rad));
	float bev = bevel * ps;
	float shade = 0.0;
	if (bev > 0.01) {
		shade = clamp(highlight, 0.0, 1.0) * dot(n_out, light) * (1.0 - smoothstep(0.0, bev, d));
	}
	vec3 outc = shade > 0.0 ? rgb + shade * (1.0 - rgb) : rgb * (1.0 + shade);
	float lw = line * ps * 0.5;
	if (lw > 0.0) {
		float k = clamp(line_dark, 0.0, 1.0) * (1.0 - smoothstep(lw - 0.5, lw + 0.5, d));
		outc *= 1.0 - k;
	}
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
