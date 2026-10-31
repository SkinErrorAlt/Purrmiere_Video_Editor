shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D mid_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform vec2 top_left = vec2(0.4, 0.62);
uniform vec2 top_right = vec2(0.6, 0.62);
uniform vec2 bottom_right = vec2(0.6, 0.71);
uniform vec2 bottom_left = vec2(0.4, 0.71);
uniform int style : hint_range(0, 2) = 0;
uniform float columns : hint_range(2.0, 30.0) = 8.0;
uniform float rows : hint_range(1.0, 10.0) = 2.0;
uniform vec4 colour : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform float grow : hint_range(0.0, 30.0) = 4.0;
uniform float feather : hint_range(0.0, 30.0) = 3.0;
uniform bool show_outline = false;

float cross2(vec2 a, vec2 b) {
	return a.x * b.y - a.y * b.x;
}

vec2 inv_bilinear(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d) {
	vec2 e = b - a;
	vec2 f = d - a;
	vec2 g = a - b + c - d;
	vec2 h = p - a;
	float k2 = cross2(g, f);
	float k1 = cross2(e, f) + cross2(h, g);
	float k0 = cross2(h, e);
	float v = -1.0;
	if (abs(k2) < 0.001 * max(abs(k1), 0.001)) {
		v = abs(k1) > 1e-6 ? -k0 / k1 : -1.0;
	} else {
		float disc = k1 * k1 - 4.0 * k0 * k2;
		if (disc < 0.0) {
			return vec2(-10.0);
		}
		float w = sqrt(disc);
		float v1 = (-k1 - w) / (2.0 * k2);
		float v2 = (-k1 + w) / (2.0 * k2);
		v = abs(v1 - 0.5) < abs(v2 - 0.5) ? v1 : v2;
	}
	vec2 axis = e + g * v;
	float u = dot(h - f * v, axis) / max(dot(axis, axis), 1e-6);
	return vec2(u, v);
}

vec2 bilinear(vec2 uv, vec2 a, vec2 b, vec2 c, vec2 d) {
	return mix(mix(a, b, uv.x), mix(d, c, uv.x), uv.y);
}

vec4 far_at(sampler2D tex, vec2 uv) {
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	uv = clamp(uv, vec2(0.0), vec2(1.0));
	vec4 s = texture(tex, uv) * 4.0;
	s += texture(tex, uv + px * vec2(-1.0, 0.0)) * 2.0;
	s += texture(tex, uv + px * vec2(1.0, 0.0)) * 2.0;
	s += texture(tex, uv + px * vec2(0.0, -1.0)) * 2.0;
	s += texture(tex, uv + px * vec2(0.0, 1.0)) * 2.0;
	s += texture(tex, uv + px * vec2(-1.0, -1.0));
	s += texture(tex, uv + px * vec2(1.0, -1.0));
	s += texture(tex, uv + px * vec2(-1.0, 1.0));
	s += texture(tex, uv + px * vec2(1.0, 1.0));
	return s / 16.0;
}

void fragment() {
	vec2 full = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	vec2 p = UV * full;
	vec2 a = top_left * full;
	vec2 b = top_right * full;
	vec2 c = bottom_right * full;
	vec2 d = bottom_left * full;
	vec2 mid = (a + b + c + d) * 0.25;
	float g = max(grow, 0.0) * 1.4142;
	a += normalize(a - mid + vec2(0.0001)) * g;
	b += normalize(b - mid + vec2(0.0001)) * g;
	c += normalize(c - mid + vec2(0.0001)) * g;
	d += normalize(d - mid + vec2(0.0001)) * g;
	vec2 q = inv_bilinear(p, a, b, c, d);
	float width_px = 0.5 * (length(b - a) + length(c - d));
	float height_px = 0.5 * (length(d - a) + length(c - b));
	float out_u = max(max(-q.x, q.x - 1.0), 0.0) * width_px;
	float out_v = max(max(-q.y, q.y - 1.0), 0.0) * height_px;
	float dist_out = q.x < -5.0 ? 1e6 : max(out_u, out_v);
	float in_u = min(q.x, 1.0 - q.x) * width_px;
	float in_v = min(q.y, 1.0 - q.y) * height_px;
	float dist_in = min(in_u, in_v);
	float fw = max(feather, 0.0);
	float cover = dist_out <= 0.0 ? 1.0 : (fw > 0.0 ? 1.0 - smoothstep(0.0, fw, dist_out) : 0.0);
	vec4 outc = texture(effect_tex, UV);
	if (cover > 0.0 && width_px > 0.5 && height_px > 0.5) {
		vec4 hid = vec4(colour.rgb * colour.a, colour.a);
		if (style == 0) {
			float br = max(height_px * 0.35, 1.0);
			vec4 s = far_at(TEXTURE, UV);
			float n = 1.0;
			for (int i = 0; i < 16; i++) {
				float fi = float(i) + 0.5;
				float rr = sqrt(fi / 16.0) * br;
				float ang = fi * 2.3999632;
				s += far_at(TEXTURE, UV + vec2(cos(ang), sin(ang)) * rr / full);
				n += 1.0;
			}
			hid = s / n;
		} else if (style == 1) {
			vec2 cells = vec2(max(columns, 1.0), max(rows, 1.0));
			vec2 cq = (floor(clamp(q, vec2(0.0), vec2(0.9999)) * cells) + 0.5) / cells;
			vec2 base = bilinear(cq, a, b, c, d) / full;
			vec2 du = (bilinear(cq + vec2(0.25 / cells.x, 0.0), a, b, c, d) / full) - base;
			vec2 dv = (bilinear(cq + vec2(0.0, 0.25 / cells.y), a, b, c, d) / full) - base;
			vec4 m = texture(mid_tex, base) + texture(mid_tex, base + du) + texture(mid_tex, base - du) + texture(mid_tex, base + dv) + texture(mid_tex, base - dv);
			hid = mix(m * 0.2, far_at(TEXTURE, base), 0.3);
		}
		outc = mix(outc, hid, cover);
	}
	if (show_outline) {
		float edge_px = dist_out > 0.0 ? dist_out : dist_in;
		float ring = q.x < -5.0 ? 0.0 : 1.0 - smoothstep(0.75, 1.75, edge_px);
		outc = mix(outc, vec4(1.0, 0.85, 0.1, 1.0), ring);
	}
	COLOR = outc;
}
