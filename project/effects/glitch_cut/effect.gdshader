shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.05, 2.0) = 0.4;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float blocks : hint_range(0.0, 1.0) = 0.7;
uniform float block_size : hint_range(8.0, 160.0) = 48.0;
uniform float tear : hint_range(0.0, 1.0) = 0.5;
uniform float colour_split : hint_range(0.0, 1.0) = 0.6;
uniform float noise : hint_range(0.0, 1.0) = 0.5;
uniform float rate : hint_range(4.0, 60.0) = 20.0;
uniform int seed : hint_range(0, 9999) = 0;

float trans_amount(out bool is_in) {
	float d = max(duration, 0.01);
	if (when == 3) {
		is_in = false;
		return clamp(progress, 0.0, 1.0);
	}
	float a_in = 0.0;
	float a_out = 0.0;
	if (when == 0 || when == 1) {
		a_in = clamp(1.0 - clip_time / d, 0.0, 1.0);
	}
	if (when == 0 || when == 2) {
		a_out = clamp(1.0 - (clip_duration - clip_time) / d, 0.0, 1.0);
	}
	is_in = a_in >= a_out;
	return max(a_in, a_out);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec4 fetch(sampler2D tex, vec2 uv) {
	return texture(tex, vec2(fract(uv.x), clamp(uv.y, 0.0, 1.0)));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_in = false;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float ps = max(px_scale, 0.0001);
		float e = pow(g, 1.3);
		float sd = float(seed) * 1.618 + 11.0;
		float st = floor(clip_time * clamp(rate, 4.0, 60.0));
		if (when == 3) {
			st = floor(clamp(progress, 0.0, 1.0) * 14.0) + floor(clip_time * clamp(rate, 4.0, 60.0));
		}
		vec2 pix = UV * sz;
		vec2 uv = UV;
		float te = clamp(tear, 0.0, 1.0) * e;
		if (hash13(vec3(st, sd, 1.0)) < te * 0.9) {
			uv.y += (hash13(vec3(st, sd, 2.0)) - 0.5) * 0.5 * te;
			uv.y = fract(uv.y);
		}
		float row_h = (6.0 + 40.0 * hash13(vec3(floor(pix.y / (24.0 * ps)), st, sd))) * ps;
		float row = floor(pix.y / row_h);
		float rh = hash13(vec3(row, st, sd + 3.0));
		if (rh < te * 0.8) {
			uv.x += (hash13(vec3(row, st, sd + 4.0)) - 0.5) * 0.45 * te;
		}
		float bs = clamp(block_size, 8.0, 160.0) * ps;
		vec2 bsz = vec2(bs * (1.0 + 2.0 * hash13(vec3(floor(pix.y / bs), st, sd + 5.0))), bs);
		vec2 cell = floor(pix / bsz);
		float be = clamp(blocks, 0.0, 1.0) * e;
		float bh = hash13(vec3(cell + vec2(sd, 0.0), st));
		bool hit = bh < be * 0.75;
		float kind = hash13(vec3(cell, st + 7.0 + sd));
		if (hit) {
			vec2 jump = vec2(hash13(vec3(cell, st + 17.0)), hash13(vec3(cell, st + 29.0))) - 0.5;
			uv += jump * vec2(0.6, 0.3) * (0.3 + 0.7 * e);
			if (kind < 0.25) {
				uv = (cell + 0.5) * bsz / sz + jump * 0.2;
			}
		}
		float cs = clamp(colour_split, 0.0, 1.0) * e * (0.01 + 0.03 * rh) * (hit ? 2.0 : 1.0);
		vec4 mid = fetch(TEXTURE, uv);
		vec4 rr = fetch(TEXTURE, uv + vec2(cs, 0.0));
		vec4 bb = fetch(TEXTURE, uv - vec2(cs, 0.0));
		vec4 o = vec4(rr.r, mid.g, bb.b, max(mid.a, max(rr.a, bb.a)));
		if (hit && kind > 0.8) {
			o = vec4(o.b, o.r, o.g, o.a);
		}
		float ne = clamp(noise, 0.0, 1.0) * smoothstep(0.35, 1.0, g);
		vec2 ncell = floor(pix / vec2(bs * 0.5, bs * 0.25));
		float nh = hash13(vec3(ncell, st + sd * 3.0));
		if (nh < ne * ne * 0.9) {
			vec2 fine = floor(pix / (3.0 * ps));
			float n = hash13(vec3(fine, st + 41.0));
			vec3 tintc = vec3(hash13(vec3(ncell, st + 5.0)), hash13(vec3(ncell, st + 6.0)), hash13(vec3(ncell, st + 8.0)));
			vec3 digital = mix(vec3(n), tintc * n * 1.6, step(0.5, hash13(vec3(ncell, st + 9.0))));
			o = vec4(clamp(digital, 0.0, 1.0), 1.0);
		}
		float lines = step(0.985 - 0.05 * e, hash12(vec2(floor(pix.y / ps), st + sd)));
		o.rgb = mix(o.rgb, vec3(o.a), lines * e * 0.6);
		COLOR = o;
	}
}
