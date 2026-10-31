shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform sampler2D spec_tex : filter_linear, repeat_disable;
uniform sampler2D wave_tex : filter_linear, repeat_disable;
uniform sampler2D beat_tex : filter_nearest, repeat_disable;
uniform int visual = 0;
uniform float level : hint_range(0.0, 1.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.75);
uniform float width : hint_range(0.05, 1.0) = 0.8;
uniform float height : hint_range(0.01, 1.0) = 0.3;
uniform float radius : hint_range(0.0, 0.6) = 0.15;
uniform float reach : hint_range(0.0, 0.6) = 0.18;
uniform float count : hint_range(1.0, 256.0) = 32.0;
uniform float gap : hint_range(0.0, 0.95) = 0.3;
uniform float thickness : hint_range(0.5, 40.0) = 3.0;
uniform float fill : hint_range(0.0, 1.0) = 0.35;
uniform float rows : hint_range(2.0, 64.0) = 16.0;
uniform bool both_ways = true;
uniform float spin : hint_range(-2.0, 2.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.15;
uniform float life : hint_range(0.1, 5.0) = 1.5;
uniform float dot_size : hint_range(1.0, 60.0) = 8.0;
uniform float speed : hint_range(0.0, 2.0) = 0.35;
uniform float gravity : hint_range(-2.0, 2.0) = 0.25;
uniform float particles : hint_range(1.0, 64.0) = 24.0;
uniform vec4 colour : source_color = vec4(1.0, 0.45, 0.75, 1.0);
uniform vec4 peak_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool peaks_on = false;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float look_height_mix : hint_range(0.0, 1.0) = 0.0;
uniform vec4 look_height_colour : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform bool look_levels = false;
uniform vec4 look_low_colour : source_color = vec4(0.302, 0.553, 1.0, 0.85);
uniform vec4 look_high_colour : source_color = vec4(1.0, 0.302, 0.302, 0.85);
uniform float look_glow : hint_range(0.0, 1.0) = 0.0;
uniform float look_round : hint_range(0.0, 1.0) = 0.0;

float hash11(float x) {
	return fract(sin(x * 127.1 + 311.7) * 43758.5453);
}

vec4 spec_at(float u) {
	return texture(spec_tex, vec2(clamp(u, 0.0, 1.0), 0.5));
}

vec4 spec_bar(float idx, float n) {
	return texture(spec_tex, vec2((idx + 0.5) / n, 0.5));
}

vec3 tint_of(vec4 d, float k) {
	vec3 c = mix(colour.rgb, look_height_colour.rgb, clamp(look_height_mix * k, 0.0, 1.0));
	if (look_levels) {
		c = mix(c, look_low_colour.rgb, clamp(d.b * look_low_colour.a, 0.0, 1.0));
		c = mix(c, look_high_colour.rgb, clamp(d.a * look_high_colour.a, 0.0, 1.0));
	}
	return c;
}

float sd_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

float sd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.000001), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 size = max(tex_size, vec2(1.0));
	float unit = min(size.x, size.y);
	vec2 px = UV * size;
	vec2 c_px = centre * size;
	float aa = 1.0;
	float dist = 1e9;
	float k = 0.0;
	vec4 d = vec4(0.0);
	float peak_cover = 0.0;
	float extra = 0.0;
	float n = max(floor(count), 1.0);
	float th = max(thickness * px_scale, 1.0);
	if (visual == 0) {
		float half_w = width * 0.5 * size.x;
		float x = abs(px.x - c_px.x);
		float cell_w = half_w / n;
		float idx = clamp(floor(x / max(cell_w, 0.0001)), 0.0, n - 1.0);
		d = spec_bar(idx, n);
		float v = clamp(d.r, 0.0, 1.0);
		float h = max(v * height * size.y, 2.0);
		float bw = max(cell_w * (1.0 - gap) * 0.5, 0.5);
		float bx = (idx + 0.5) * cell_w;
		vec2 q;
		vec2 hs;
		if (both_ways) {
			q = vec2(x - bx, px.y - c_px.y);
			hs = vec2(bw, h * 0.5);
			k = clamp(abs(px.y - c_px.y) / max(height * size.y * 0.5, 0.0001), 0.0, 1.0);
		} else {
			q = vec2(x - bx, px.y - (c_px.y - h * 0.5));
			hs = vec2(bw, h * 0.5);
			k = clamp((c_px.y - px.y) / max(height * size.y, 0.0001), 0.0, 1.0);
		}
		dist = sd_box(q, hs, look_round * min(bw, hs.y));
		if (peaks_on) {
			float pk = clamp(d.g, 0.0, 1.0) * height * size.y;
			float py = both_ways ? abs(px.y - c_px.y) - pk * 0.5 : (c_px.y - px.y) - pk;
			peak_cover = step(abs(x - bx), bw) * (1.0 - smoothstep(1.0, 2.0, abs(py - 1.5)));
		}
		if (x > half_w) {
			dist = max(dist, x - half_w);
		}
	} else if (visual == 1) {
		float left = c_px.x - width * 0.5 * size.x;
		float u = (px.x - left) / max(width * size.x, 0.0001);
		if (u >= 0.0 && u <= 1.0) {
			d = spec_at(u);
			float e = 1.0 / max(width * size.x, 1.0);
			float v = clamp(d.r, 0.0, 1.0);
			float v2 = clamp(spec_at(u + e).r, 0.0, 1.0);
			float y = c_px.y - v * height * size.y;
			float slope = (v2 - v) * height * size.y;
			float dy = px.y - y;
			dist = abs(dy) / sqrt(1.0 + slope * slope) - th * 0.5;
			k = clamp((c_px.y - px.y) / max(height * size.y, 0.0001), 0.0, 1.0);
			if (dy > 0.0 && px.y <= c_px.y) {
				extra = fill * (1.0 - 0.6 * clamp(dy / max(v * height * size.y, 1.0), 0.0, 1.0));
			}
			if (peaks_on) {
				float yp = c_px.y - clamp(d.g, 0.0, 1.0) * height * size.y;
				peak_cover = (1.0 - smoothstep(0.5, 1.5, abs(px.y - yp))) * 0.8;
			}
		}
	} else if (visual == 2) {
		float left = c_px.x - width * 0.5 * size.x;
		float cell_w = width * size.x / n;
		float idx = floor((px.x - left) / max(cell_w, 0.0001));
		if (idx >= 0.0 && idx < n) {
			d = spec_bar(idx, n);
			float rcount = max(floor(rows), 1.0);
			float cell_h = height * size.y / rcount;
			float row = floor((c_px.y - px.y) / max(cell_h, 0.0001));
			if (row >= 0.0 && row < rcount) {
				float lit = clamp(d.r, 0.0, 1.0) * rcount;
				vec2 cc = vec2(left + (idx + 0.5) * cell_w, c_px.y - (row + 0.5) * cell_h);
				float rr = max(min(cell_w, cell_h) * (1.0 - gap) * 0.5, 0.5);
				float dd = length(px - cc) - rr;
				if (row + 0.5 < lit + 0.5 && row < ceil(lit - 0.25)) {
					dist = dd;
				} else {
					extra = 0.12 * (1.0 - smoothstep(-1.0, 1.0, dd));
				}
				k = (row + 0.5) / rcount;
				if (peaks_on) {
					float prow = floor(clamp(d.g, 0.0, 1.0) * rcount - 0.0001);
					peak_cover = (row == prow && prow >= ceil(lit - 0.25)) ? (1.0 - smoothstep(-1.0, 1.0, dd)) : 0.0;
				}
			}
		}
	} else if (visual == 3 || visual == 4) {
		vec2 p = (px - c_px) / unit;
		float r = length(p);
		float ang = atan(p.x, -p.y) / 6.28318530718 + 0.5 + clip_time * spin;
		float f = fract(ang);
		float r0 = radius * (1.0 + pulse * level);
		if (visual == 3) {
			float cell = f * n;
			float idx = floor(cell);
			float mid = (idx + 0.5) / n;
			d = spec_at(1.0 - abs(mid * 2.0 - 1.0));
			float v = clamp(d.r, 0.0, 1.0);
			float a = (mid - 0.5 - clip_time * spin) * 6.28318530718;
			vec2 dir = vec2(sin(a), -cos(a));
			vec2 a_px = c_px + dir * r0 * unit;
			vec2 b_px = c_px + dir * (r0 + max(v * reach, 0.002)) * unit;
			float w = th * 0.5;
			dist = sd_segment(px, a_px, b_px) - w;
			if (look_round <= 0.0) {
				vec2 ba = normalize(b_px - a_px + vec2(0.000001));
				float along = dot(px - a_px, ba);
				float lenp = length(b_px - a_px);
				dist = max(dist, max(-along, along - lenp));
			}
			k = clamp((r - r0) / max(reach, 0.0001), 0.0, 1.0);
			if (peaks_on) {
				float rp = r0 + clamp(d.g, 0.0, 1.0) * reach;
				peak_cover = (1.0 - smoothstep(w, w + 1.0, sd_segment(px, c_px + dir * rp * unit, c_px + dir * rp * unit))) * 0.9;
			}
		} else {
			float u = 1.0 - abs(f * 2.0 - 1.0);
			d = texture(wave_tex, vec2(u, 0.5));
			float v = clamp(d.r, 0.0, 1.0);
			float rw = r0 + v * reach;
			dist = abs(r - rw) * unit - th * 0.5;
			k = clamp((r - r0) / max(reach, 0.0001), 0.0, 1.0);
			if (r < rw) {
				extra = fill * (1.0 - smoothstep(r0 * 0.6, rw, rw - r + r0 * 0.6));
			}
		}
	} else {
		float best = 1e9;
		float best_k = 0.0;
		float cnt = max(floor(particles), 1.0);
		for (int b = 0; b < 12; b++) {
			vec4 bt = texture(beat_tex, vec2((float(b) + 0.5) / 12.0, 0.5));
			if (bt.a < 0.5 || bt.r < 0.0 || bt.r > life) {
				continue;
			}
			float age = bt.r;
			float fade = 1.0 - age / life;
			for (int j = 0; j < 64; j++) {
				if (float(j) >= cnt) {
					break;
				}
				float s = bt.b * 97.0 + float(j) * 1.618;
				float a = hash11(s) * 6.28318530718;
				float sp = speed * (0.35 + 0.65 * hash11(s + 7.3)) * (0.5 + 0.5 * bt.g);
				vec2 pos = c_px + (vec2(cos(a), sin(a)) * sp * age + vec2(0.0, gravity * age * age)) * unit;
				float rad = max(dot_size * px_scale * fade * (0.5 + 0.5 * bt.g), 0.5);
				float dd = length(px - pos) - rad;
				if (dd < best) {
					best = dd;
					best_k = fade;
				}
			}
		}
		dist = best;
		k = 1.0 - best_k;
		d = vec4(level, level, 0.0, 0.0);
	}
	float cover = 1.0 - smoothstep(-aa, aa, dist);
	float glow = look_glow > 0.0 ? look_glow * exp(-max(dist, 0.0) / max(18.0 * look_glow * px_scale, 0.5)) * 0.7 : 0.0;
	float shape_a = clamp(max(cover, extra), 0.0, 1.0);
	vec3 tint = tint_of(d, k);
	float a_shape = clamp(shape_a * colour.a * opacity, 0.0, 1.0);
	float a_glow = clamp(glow * (1.0 - shape_a) * colour.a * opacity, 0.0, 1.0);
	float a_peak = clamp(peak_cover * peak_colour.a * opacity, 0.0, 1.0);
	vec4 out_c = base * (1.0 - a_glow) + vec4(tint * a_glow, a_glow);
	out_c = out_c * (1.0 - a_shape) + vec4(tint * a_shape, a_shape);
	out_c = out_c * (1.0 - a_peak) + vec4(peak_colour.rgb * a_peak, a_peak);
	COLOR = out_c;
}
