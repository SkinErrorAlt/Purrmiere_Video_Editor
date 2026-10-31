shader_type canvas_item;
render_mode blend_disabled;

uniform float level : hint_range(0.0, 255.0) = 128.0;
uniform int edge : hint_range(0, 1) = 0;
uniform int lines_from : hint_range(0, 1) = 0;
uniform float line_width : hint_range(0.5, 8.0) = 1.5;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

vec3 unpremul(vec4 c) {
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
}

vec3 contour(vec3 v, vec3 gx, vec3 gy, float lv, float side, float w, float aa) {
	vec3 gm = sqrt(gx * gx + gy * gy);
	vec3 sd = side * (v - lv) / max(gm, vec3(0.0001));
	vec3 band = smoothstep(vec3(-aa), vec3(aa), sd) * (vec3(1.0) - smoothstep(vec3(w - aa), vec3(w + aa), sd));
	return band * step(vec3(0.0015), gm);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = unpremul(c);
	float ps = max(px_scale, 0.0001);
	vec2 e = vec2(ps) / max(tex_size, vec2(1.0));
	vec3 l = unpremul(texture(TEXTURE, UV - vec2(e.x, 0.0)));
	vec3 r = unpremul(texture(TEXTURE, UV + vec2(e.x, 0.0)));
	vec3 u = unpremul(texture(TEXTURE, UV - vec2(0.0, e.y)));
	vec3 d = unpremul(texture(TEXTURE, UV + vec2(0.0, e.y)));
	float lv = level / 255.0;
	float side = edge == 1 ? 1.0 : -1.0;
	float aa = 0.5 / ps;
	float w = max(line_width, 0.5);
	vec3 outc;
	if (lines_from == 1) {
		vec3 wl = vec3(0.2126, 0.7152, 0.0722);
		vec3 line = contour(vec3(dot(rgb, wl)), vec3((dot(r, wl) - dot(l, wl)) * 0.5), vec3((dot(d, wl) - dot(u, wl)) * 0.5), lv, side, w, aa);
		outc = vec3(1.0 - line.x);
	} else {
		outc = vec3(1.0) - contour(rgb, (r - l) * 0.5, (d - u) * 0.5, lv, side, w, aa);
	}
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
