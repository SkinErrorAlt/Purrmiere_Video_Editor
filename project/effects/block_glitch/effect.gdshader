shader_type canvas_item;
render_mode blend_disabled;

uniform float amount : hint_range(0.0, 1.0) = 0.35;
uniform float block_size : hint_range(4.0, 200.0) = 40.0;
uniform float displace : hint_range(0.0, 400.0) = 96.0;
uniform float flatten : hint_range(0.0, 1.0) = 0.3;
uniform float stretch : hint_range(0.0, 1.0) = 0.3;
uniform float colour_swap : hint_range(0.0, 1.0) = 0.25;
uniform float rate : hint_range(0.0, 30.0) = 8.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 hash32(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yzz) * p3.zyx);
}

vec4 fetch(sampler2D tex, vec2 pix, vec2 size) {
	return texture(tex, clamp(pix / size, vec2(0.0), vec2(1.0)));
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float bs = max(block_size * ps, 2.0);
	float frame = rate > 0.0 ? mod(floor(clip_time * rate), 4096.0) : 0.0;
	vec2 sk = vec2(mod(float(seed), 997.0) * 1.731 + 5.0, frame * 0.917 + 3.0);
	vec2 pix = UV * size;
	vec2 big = floor(pix / bs);
	float row = mod(big.y, 1024.0);
	float row_heat = hash12(vec2(row, 3.1) + sk);
	float heat = clamp(amount, 0.0, 1.0) * (0.15 + 1.7 * row_heat * row_heat);
	float run_len = 2.0 + floor(hash12(vec2(row, 9.0) + sk) * 7.0);
	float run_shift = floor(hash12(vec2(row, 13.0) + sk) * run_len);
	float run = mod(floor((big.x + run_shift) / run_len), 1024.0);
	vec3 hr = hash32(vec2(run, row) + sk + 29.0);
	vec3 hb = hash32(mod(big, 1024.0) + sk + 71.0);
	bool hit = hr.x < heat * 0.75 || hb.x < heat * 0.05;
	if (!hit) {
		COLOR = texture(TEXTURE, UV);
	} else {
		float sub = step(hb.y, 0.3);
		float us = mix(bs, bs * 0.5, sub);
		vec2 unit = floor(pix / us);
		vec3 hu = hash32(mod(unit, 2048.0) + sk + vec2(sub * 131.0, 97.0));
		vec3 h2 = hash32(vec2(run, row) + sk + 53.0);
		vec2 off = (h2.xy - 0.5) * 2.0 * displace * ps;
		off.y *= 0.3;
		off = floor(off / bs + 0.5) * bs;
		vec2 origin = unit * us;
		vec2 local = pix - origin;
		vec2 src = pix + off;
		if (hr.y < stretch) {
			src.y = big.y * bs + off.y + 0.5;
		}
		vec4 c = fetch(TEXTURE, src, size);
		if (hu.y < flatten) {
			vec2 mid = origin + off + vec2(us * 0.5);
			float q = us * 0.3;
			c = (fetch(TEXTURE, mid + vec2(-q, -q), size) + fetch(TEXTURE, mid + vec2(q, -q), size) + fetch(TEXTURE, mid + vec2(-q, q), size) + fetch(TEXTURE, mid + vec2(q, q), size)) * 0.25;
			float grad = (local.x / us - 0.5) * 0.12 * (hu.z - 0.5);
			c.rgb = clamp(c.rgb + vec3(grad) * c.a, vec3(0.0), vec3(c.a));
		}
		float a = c.a;
		vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
		if (hr.z < colour_swap) {
			float pick = fract(hr.z * 7.13 + h2.z);
			if (pick < 0.34) {
				rgb = rgb.brg;
			} else if (pick < 0.67) {
				rgb = rgb.gbr;
			} else {
				rgb = vec3(rgb.r, 1.0 - rgb.g, rgb.b);
			}
		}
		rgb = floor(clamp(rgb, 0.0, 1.0) * 15.0 + 0.5) / 15.0;
		COLOR = vec4(rgb * a, a);
	}
}
