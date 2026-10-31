shader_type canvas_item;
render_mode blend_disabled;

uniform float size : hint_range(4.0, 200.0) = 24.0;
uniform float jitter : hint_range(0.0, 1.0) = 0.9;
uniform float edge_width : hint_range(0.0, 10.0) = 0.0;
uniform vec4 edge_colour : source_color = vec4(0.08, 0.08, 0.08, 1.0);
uniform float animate : hint_range(0.0, 5.0) = 0.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

vec2 seed_offset(int s) {
	float f = float(s);
	return vec2(mod(f * 12.9898, 997.0), mod(f * 78.233, 991.0));
}

vec2 cell_point(vec2 cell, vec2 so) {
	vec2 o = hash22(cell + so);
	if (animate > 0.0) {
		o = 0.5 + 0.5 * sin(max(clip_time, 0.0) * animate + 6.2831853 * o);
	}
	return cell + 0.5 + (o - 0.5) * clamp(jitter, 0.0, 1.0);
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float cell_px = max(size * px_scale, 2.0);
	vec2 p = UV * dims / cell_px;
	vec2 base = floor(p);
	vec2 so = seed_offset(seed);
	float best = 1e9;
	vec2 bp = base + 0.5;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 pt = cell_point(base + vec2(float(x), float(y)), so);
			vec2 dv = pt - p;
			float d = dot(dv, dv);
			if (d < best) {
				best = d;
				bp = pt;
			}
		}
	}
	vec4 c = texture(TEXTURE, clamp(bp * cell_px / dims, vec2(0.0), vec2(1.0)));
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	if (edge_width > 0.0) {
		float edge_d = 1e9;
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 pt = cell_point(base + vec2(float(x), float(y)), so);
				vec2 diff = pt - bp;
				float len = length(diff);
				if (len > 0.0001) {
					edge_d = min(edge_d, dot((bp + pt) * 0.5 - p, diff / len));
				}
			}
		}
		float edge_px = max(edge_d, 0.0) * cell_px;
		float half_w = edge_width * px_scale * 0.5;
		float cover = 1.0 - smoothstep(half_w - 0.5, half_w + 0.5, edge_px);
		rgb = mix(rgb, edge_colour.rgb, cover * edge_colour.a);
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
