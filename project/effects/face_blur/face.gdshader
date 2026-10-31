shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D mid_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform vec2 centre = vec2(0.5, 0.4);
uniform float size : hint_range(0.02, 1.0) = 0.25;
uniform float stretch : hint_range(0.3, 3.0) = 0.8;
uniform float rotation : hint_range(-180.0, 180.0) = 0.0;
uniform int shape : hint_range(0, 1) = 0;
uniform int style : hint_range(0, 2) = 0;
uniform float blocks : hint_range(3.0, 40.0) = 9.0;
uniform vec4 colour : source_color = vec4(0.05, 0.05, 0.05, 1.0);
uniform float feather : hint_range(0.0, 1.0) = 0.2;
uniform bool second = false;
uniform vec2 centre_2 = vec2(0.7, 0.4);
uniform float size_2 : hint_range(0.02, 1.0) = 0.25;
uniform bool show_outline = false;

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

mat2 turn(float deg) {
	float a = radians(deg);
	return mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
}

float shape_e(vec2 l, vec2 axes) {
	if (shape == 1) {
		float cr = 0.35 * min(axes.x, axes.y);
		vec2 q = abs(l) - axes + vec2(cr);
		float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - cr;
		return 1.0 + sd / max(min(axes.x, axes.y), 0.0001);
	}
	return length(l / max(axes, vec2(0.0001)));
}

vec4 hidden(sampler2D tex, vec2 c_uv, vec2 l, vec2 axes, vec2 full, float r) {
	if (style == 2) {
		return vec4(colour.rgb * colour.a, colour.a);
	}
	mat2 back = turn(rotation);
	if (style == 1) {
		float cell = max(2.0 * axes.x / max(blocks, 1.0), 1.0);
		vec2 lc = (floor(l / cell) + 0.5) * cell;
		vec2 base = c_uv + (back * lc) / full;
		vec2 q = (back * vec2(cell * 0.25, 0.0)) / full;
		vec2 q2 = (back * vec2(0.0, cell * 0.25)) / full;
		vec4 m = texture(mid_tex, base) + texture(mid_tex, base + q) + texture(mid_tex, base - q) + texture(mid_tex, base + q2) + texture(mid_tex, base - q2);
		m *= 0.2;
		vec4 f = far_at(tex, base);
		return mix(m, f, smoothstep(12.0, 32.0, cell));
	}
	vec2 here = c_uv + (back * l) / full;
	float br = max(r * 0.35, 4.0);
	float to_far = smoothstep(24.0, 64.0, br);
	vec4 s = mix(texture(mid_tex, here), far_at(tex, here), to_far);
	float n = 1.0;
	for (int i = 0; i < 24; i++) {
		float fi = float(i) + 0.5;
		float rr = sqrt(fi / 24.0) * br;
		float ang = fi * 2.3999632;
		vec2 o = (vec2(cos(ang), sin(ang)) * rr) / full;
		s += mix(texture(mid_tex, here + o), far_at(tex, here + o), to_far);
		n += 1.0;
	}
	return s / n;
}

void spot(sampler2D tex, vec2 uv, vec2 c_uv, float sz, vec2 full, inout vec4 outc, inout float ring) {
	vec2 d = (uv - c_uv) * full;
	vec2 l = turn(-rotation) * d;
	float r = max(sz, 0.001) * full.y * 0.5;
	vec2 axes = vec2(r * max(stretch, 0.05), r);
	float e = shape_e(l, axes);
	float fw = max(clamp(feather, 0.0, 1.0) * 0.6, 2.0 / max(r, 1.0));
	float cover = 1.0 - smoothstep(1.0, 1.0 + fw, e);
	if (cover > 0.0) {
		outc = mix(outc, hidden(tex, c_uv, l, axes, full, r), cover);
	}
	float edge_px = abs(e - 1.0) * min(axes.x, axes.y);
	ring = max(ring, 1.0 - smoothstep(0.75, 1.75, edge_px));
}

void fragment() {
	vec2 full = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	vec4 outc = texture(effect_tex, UV);
	float ring = 0.0;
	spot(TEXTURE, UV, centre, size, full, outc, ring);
	if (second) {
		spot(TEXTURE, UV, centre_2, size_2, full, outc, ring);
	}
	if (show_outline) {
		outc = mix(outc, vec4(1.0, 0.85, 0.1, 1.0), ring);
	}
	COLOR = outc;
}
