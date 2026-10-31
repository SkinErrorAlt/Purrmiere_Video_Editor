shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int levels : hint_range(2, 8) = 4;
uniform float saturation : hint_range(0.0, 2.0) = 1.35;
uniform float outline : hint_range(0.0, 1.0) = 0.6;
uniform float line_width : hint_range(0.5, 6.0) = 1.5;
uniform float dots : hint_range(0.0, 1.0) = 0.6;
uniform float dot_size : hint_range(3.0, 40.0) = 8.0;
uniform vec4 paper_colour : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform vec4 ink_colour : source_color = vec4(0.05, 0.04, 0.06, 1.0);

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
}

float luma_at(sampler2D tex, vec2 uv) {
	return dot(straight(texture(tex, clamp(uv, vec2(0.0), vec2(1.0)))), LUMA);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 px = 1.0 / sz;
	vec3 base = straight(c) * 0.4;
	base += straight(texture(TEXTURE, UV + px * vec2(1.0, 0.0))) * 0.15;
	base += straight(texture(TEXTURE, UV - px * vec2(1.0, 0.0))) * 0.15;
	base += straight(texture(TEXTURE, UV + px * vec2(0.0, 1.0))) * 0.15;
	base += straight(texture(TEXTURE, UV - px * vec2(0.0, 1.0))) * 0.15;
	float l = dot(base, LUMA);
	vec3 col = clamp(mix(vec3(l), base, clamp(saturation, 0.0, 2.0)), 0.0, 1.0);
	float n = float(clamp(levels, 2, 8));
	float lf = l * n;
	float lq = clamp((floor(lf) + smoothstep(0.42, 0.58, fract(lf))) / n, 0.0, 1.0);
	float lc = max(dot(col, LUMA), 0.0001);
	vec3 flat_col = clamp(col * (max(lq, 0.08) / lc), 0.0, 1.0);
	flat_col = mix(flat_col, paper_colour.rgb, smoothstep(0.82, 1.0, lq));
	float cell = max(dot_size * ps, 2.0);
	vec2 pp = UV * sz;
	vec2 rp = vec2(pp.x + pp.y, pp.y - pp.x) * 0.70710678 / cell;
	vec2 fc = fract(rp) - 0.5;
	float dark = clamp(1.0 - lq * 1.25, 0.0, 1.0);
	float r = sqrt(dark) * 0.62;
	float dd = length(fc);
	float aa = 0.8 / cell;
	float dot_m = (1.0 - smoothstep(r - aa, r + aa, dd)) * step(0.02, dark);
	flat_col = mix(flat_col, flat_col * 0.3 + ink_colour.rgb * 0.2, dot_m * clamp(dots, 0.0, 1.0));
	vec2 o = px * max(line_width * ps, 0.5);
	float tl = luma_at(TEXTURE, UV + vec2(-o.x, -o.y));
	float t = luma_at(TEXTURE, UV + vec2(0.0, -o.y));
	float tr = luma_at(TEXTURE, UV + vec2(o.x, -o.y));
	float ml = luma_at(TEXTURE, UV + vec2(-o.x, 0.0));
	float mr = luma_at(TEXTURE, UV + vec2(o.x, 0.0));
	float bl = luma_at(TEXTURE, UV + vec2(-o.x, o.y));
	float b = luma_at(TEXTURE, UV + vec2(0.0, o.y));
	float br = luma_at(TEXTURE, UV + vec2(o.x, o.y));
	float gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
	float gy = (bl + 2.0 * b + br) - (tl + 2.0 * t + tr);
	float edge = length(vec2(gx, gy));
	float ol = clamp(outline, 0.0, 1.0);
	float thr = mix(0.9, 0.12, ol);
	float line = smoothstep(thr, thr * 1.5, edge) * step(0.001, ol);
	vec3 outc = mix(flat_col, ink_colour.rgb, line);
	COLOR = vec4(clamp(outc, 0.0, 1.0) * c.a, c.a);
}
