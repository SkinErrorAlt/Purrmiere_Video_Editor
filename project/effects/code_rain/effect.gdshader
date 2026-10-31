shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 colour : source_color = vec4(0.25, 1.0, 0.45, 1.0);
uniform vec4 head_colour : source_color = vec4(0.85, 1.0, 0.9, 1.0);
uniform float glyph_size : hint_range(6.0, 80.0) = 16.0;
uniform float density : hint_range(0.0, 1.0) = 0.55;
uniform float speed : hint_range(0.0, 4.0) = 1.0;
uniform float trail : hint_range(0.0, 1.0) = 0.5;
uniform float change_rate : hint_range(0.0, 30.0) = 6.0;
uniform float darken : hint_range(0.0, 1.0) = 0.35;
uniform int seed : hint_range(0, 9999) = 0;
uniform int blend : hint_range(0, 6) = 2;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec4 hash42(vec2 p) {
	vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	p4 += dot(p4, p4.wzxy + 33.33);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

vec3 blend_colour(vec3 base, vec3 over, int how) {
	if (how == 1) { return base * over; }
	if (how == 2) { return 1.0 - (1.0 - base) * (1.0 - over); }
	if (how == 3) { return mix(2.0 * base * over, 1.0 - 2.0 * (1.0 - base) * (1.0 - over), step(0.5, base)); }
	if (how == 4) { return base + over; }
	if (how == 5) { return (1.0 - 2.0 * over) * base * base + 2.0 * over * base; }
	return over;
}

vec4 mix_in(vec3 pic, float pic_a, vec3 gen, float cov, int how, float amt) {
	vec3 pc = clamp(pic, 0.0, 1.0);
	vec3 g = clamp(gen, 0.0, 1.0);
	float s = clamp(amt, 0.0, 1.0);
	float k = clamp(cov, 0.0, 1.0);
	if (how == 0) {
		return mix(vec4(pc * pic_a, pic_a), vec4(g * k, k), s);
	}
	if (how == 6) {
		float w = k * s;
		return vec4(g * w + pc * pic_a * (1.0 - w), w + pic_a * (1.0 - w));
	}
	vec3 o = mix(pc, blend_colour(pc, g, how), k * s);
	return vec4(clamp(o, 0.0, 1.0) * pic_a, pic_a);
}

float glyph(vec2 local, vec2 gid, float variant) {
	vec2 g = floor(vec2(local.x * 7.0 - 1.0, local.y * 9.0 - 1.0));
	if (g.x < 0.0 || g.x > 4.0 || g.y < 0.0 || g.y > 6.0) {
		return 0.0;
	}
	vec4 h = hash42(gid + variant * 1.7);
	if (h.x < 0.5) {
		g.x = min(g.x, 4.0 - g.x);
	}
	float bit = hash12(vec2(g.x + gid.x * 5.0, g.y + gid.y * 7.0) + variant * 3.3 + h.yz * 91.0);
	return step(0.52, bit);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 pix = UV * sz;
	float gw = max(glyph_size * ps, 3.0);
	float gh = gw * 1.25;
	float col = floor(pix.x / gw);
	float row = floor(pix.y / gh);
	vec2 local = fract(pix / vec2(gw, gh));
	float rows = ceil(sz.y / gh);
	vec2 sk = vec2(mod(float(seed), 997.0) * 1.913 + 4.0, mod(float(seed), 991.0) * 0.271 + 8.0);
	float bright = 0.0;
	float head = 0.0;
	for (int s = 0; s < 2; s++) {
		vec4 h = hash42(vec2(mod(col, 2048.0), float(s) * 17.0 + 3.0) + sk);
		float share = clamp(density, 0.0, 1.0) * (s == 0 ? 1.0 : 0.6);
		if (h.x > share) {
			continue;
		}
		float rows_per_s = max(speed, 0.0) * (5.0 + 12.0 * h.y);
		float trail_rows = max(2.0, rows * (0.15 + 0.85 * clamp(trail, 0.0, 1.0)) * (0.5 + h.z));
		float cycle = rows + trail_rows + 6.0;
		float pos = mod(clip_time * rows_per_s + h.w * cycle, cycle);
		float behind = floor(pos) - row;
		if (behind >= 0.0 && behind < trail_rows) {
			float f = 1.0 - behind / trail_rows;
			bright = max(bright, f * f);
			if (behind < 1.0) {
				head = 1.0;
			}
		}
	}
	float cov = 0.0;
	vec3 gen = colour.rgb;
	if (bright > 0.0) {
		vec2 gid = vec2(mod(col, 1024.0), mod(row, 1024.0)) + sk;
		float cr = max(change_rate, 0.0);
		float speed_k = 0.5 + hash12(gid + 11.0);
		float variant = cr > 0.0 ? mod(floor(clip_time * cr * speed_k), 512.0) : 0.0;
		if (head > 0.5 && cr > 0.0) {
			variant = mod(floor(clip_time * cr * 3.0), 512.0);
		}
		float on = glyph(local, gid, variant);
		cov = on * bright + bright * 0.08;
		gen = mix(colour.rgb, head_colour.rgb, head);
		cov *= mix(colour.a, head_colour.a, head);
	}
	rgb *= 1.0 - clamp(darken, 0.0, 1.0) * clamp(strength, 0.0, 1.0);
	COLOR = mix_in(rgb, a, gen, clamp(cov, 0.0, 1.0), blend, strength);
}
