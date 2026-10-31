shader_type canvas_item;
render_mode blend_disabled;

uniform int kind = 0;
uniform float size : hint_range(4.0, 400.0) = 40.0;
uniform float depth : hint_range(0.0, 100.0) = 30.0;
uniform int depth_from = 0;
uniform bool solid = false;
uniform bool flat_edges = true;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float block_top(sampler2D tex, vec2 id, vec2 dims, float cell, float hmax, vec2 so) {
	if (flat_edges) {
		vec2 lo = id * cell;
		vec2 hi = lo + cell;
		if (lo.x < -0.5 || lo.y < -0.5 || hi.x > dims.x + 0.5 || hi.y > dims.y + 0.5) {
			return 0.0;
		}
	}
	float h;
	if (depth_from == 1) {
		vec4 c = texture(tex, clamp((id + 0.5) * cell / dims, vec2(0.0), vec2(1.0)));
		h = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
	} else {
		h = hash12(id + so);
	}
	return clamp(h, 0.0, 1.0) * hmax;
}

float field(sampler2D tex, vec2 b, vec2 dims, float cell, float hmax, vec2 so) {
	vec2 g = b / cell;
	vec2 id = floor(g);
	float top = block_top(tex, id, dims, cell, hmax, so);
	if (kind == 1) {
		vec2 l = abs(fract(g) - 0.5);
		top *= clamp(1.0 - 2.0 * max(l.x, l.y), 0.0, 1.0);
	}
	return top;
}

vec4 block_colour(sampler2D tex, vec2 id, vec2 dims, float cell) {
	vec4 s = vec4(0.0);
	s += texture(tex, clamp((id + vec2(0.5, 0.5)) * cell / dims, vec2(0.0), vec2(1.0))) * 2.0;
	s += texture(tex, clamp((id + vec2(0.25, 0.25)) * cell / dims, vec2(0.0), vec2(1.0)));
	s += texture(tex, clamp((id + vec2(0.75, 0.25)) * cell / dims, vec2(0.0), vec2(1.0)));
	s += texture(tex, clamp((id + vec2(0.25, 0.75)) * cell / dims, vec2(0.0), vec2(1.0)));
	s += texture(tex, clamp((id + vec2(0.75, 0.75)) * cell / dims, vec2(0.0), vec2(1.0)));
	return s / 6.0;
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float cell = max(size * max(px_scale, 0.0001), 2.0);
	float hmax = clamp(depth, 0.0, 100.0) / 100.0 * 0.45;
	float sf = float(seed);
	vec2 so = vec2(mod(sf * 12.9898, 997.0), mod(sf * 78.233, 991.0));
	vec2 p = UV * dims;
	vec2 c = dims * 0.5;
	vec4 col = texture(TEXTURE, UV);
	if (hmax > 0.00001) {
		const int STEPS = 48;
		float h_hi = hmax;
		float h_lo = 0.0;
		bool hit = false;
		vec2 b0 = c + (p - c) * (1.0 - hmax);
		if (field(TEXTURE, b0, dims, cell, hmax, so) >= hmax - 0.000001) {
			hit = true;
			h_lo = hmax;
			h_hi = hmax;
		} else {
			for (int i = 1; i <= STEPS; i++) {
				float h = hmax * (1.0 - float(i) / float(STEPS));
				vec2 b = c + (p - c) * (1.0 - h);
				if (field(TEXTURE, b, dims, cell, hmax, so) >= h) {
					h_lo = h;
					hit = true;
					break;
				}
				h_hi = h;
			}
		}
		if (hit) {
			for (int k = 0; k < 7; k++) {
				float hm = 0.5 * (h_hi + h_lo);
				vec2 bm = c + (p - c) * (1.0 - hm);
				if (field(TEXTURE, bm, dims, cell, hmax, so) >= hm) {
					h_lo = hm;
				} else {
					h_hi = hm;
				}
			}
			vec2 b_hit = c + (p - c) * (1.0 - h_lo);
			vec2 b_above = c + (p - c) * (1.0 - h_hi);
			vec2 id_hit = floor(b_hit / cell);
			vec2 id_above = floor(b_above / cell);
			vec4 face = solid || kind == 1 ? block_colour(TEXTURE, id_hit, dims, cell) : texture(TEXTURE, clamp(b_hit / dims, vec2(0.0), vec2(1.0)));
			if (kind == 1) {
				vec2 l = fract(b_hit / cell) - 0.5;
				float shade = 1.0;
				if (abs(l.x) > abs(l.y)) {
					shade = l.x > 0.0 ? 0.62 : 1.08;
				} else {
					shade = l.y > 0.0 ? 0.5 : 1.15;
				}
				float top = block_top(TEXTURE, id_hit, dims, cell, hmax, so);
				shade = mix(1.0, shade, clamp(top / max(hmax, 0.0001) * 1.5, 0.0, 1.0));
				col = vec4(min(face.rgb * shade, vec3(face.a)), face.a);
			} else if (id_above == id_hit || h_lo >= hmax) {
				col = face;
			} else {
				vec2 step_id = id_hit - id_above;
				float shade = 1.0;
				if (abs(step_id.x) >= abs(step_id.y)) {
					shade = step_id.x > 0.0 ? 0.78 : 0.5;
				} else {
					shade = step_id.y > 0.0 ? 0.88 : 0.42;
				}
				vec4 wall = block_colour(TEXTURE, id_hit, dims, cell);
				col = vec4(wall.rgb * shade, wall.a);
			}
		}
	}
	COLOR = col;
}
