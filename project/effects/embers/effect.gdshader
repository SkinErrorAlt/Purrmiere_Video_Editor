shader_type canvas_item;
render_mode blend_disabled;

uniform float amount : hint_range(0.0, 1.0) = 0.35;
uniform float size : hint_range(0.5, 30.0) = 4.5;
uniform float rise : hint_range(0.0, 3.0) = 0.6;
uniform float wind : hint_range(-2.0, 2.0) = 0.3;
uniform float sway : hint_range(0.0, 1.0) = 0.5;
uniform float flicker : hint_range(0.0, 1.0) = 0.6;
uniform float streak : hint_range(0.0, 1.0) = 0.4;
uniform float glow : hint_range(0.0, 1.0) = 0.6;
uniform vec4 colour : source_color = vec4(1.0, 0.5, 0.12, 1.0);
uniform float colour_spread : hint_range(0.0, 1.0) = 0.35;
uniform int seed : hint_range(0, 9999) = 0;
uniform int blend : hint_range(0, 6) = 4;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

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

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 pos = UV * sz;
	float t = clip_time;
	vec2 skey = floor(hash42(vec2(mod(float(seed), 997.0) * 0.7123 + 3.1, 11.7)).xy * 997.0);
	vec3 acc = vec3(0.0);
	for (int li = 0; li < 3; li++) {
		float fl = float(li);
		float depth = 1.0 - fl * 0.3;
		float r = max(size * ps * depth, 0.35);
		float cell = max(r * 34.0, 12.0 * ps);
		vec2 vel = vec2(wind * 0.15, -0.18 * max(rise, 0.0)) * sz.y * (0.4 + 0.6 * depth);
		vec2 q = pos - mod(vel * t, vec2(cell * 1024.0));
		vec2 g = q / cell + hash42(vec2(fl * 3.7, 1.9) + skey).xy * 50.0;
		vec2 cid = floor(g);
		vec2 f = g - cid;
		vec4 h = hash42(mod(cid, 1024.0) + vec2(fl * 1031.0, 0.0) + skey);
		if (h.x >= amount) {
			continue;
		}
		vec2 ctr = 0.3 + 0.4 * h.yz;
		ctr.x += clamp(sway, 0.0, 1.0) * 0.08 * sin(t * (0.8 + 1.2 * h.y) + 6.2831853 * h.z);
		ctr.y += clamp(sway, 0.0, 1.0) * 0.05 * sin(t * (1.3 + 0.9 * h.w) + 6.2831853 * h.y);
		vec2 local = (f - ctr) * cell;
		float speed_px = length(vel);
		vec2 tail_dir = speed_px > 0.001 ? -vel / speed_px : vec2(0.0, 1.0);
		float len = min(clamp(streak, 0.0, 1.0) * speed_px * 0.12 + 0.001, cell * 0.2);
		float along = clamp(dot(local, tail_dir) / len, 0.0, 1.0);
		float dist = length(local - tail_dir * len * along);
		float core = 1.0 - smoothstep(r * 0.5, r * 0.5 + 0.8 * ps, dist);
		core *= 1.0 - along * 0.75;
		float halo = exp(-dist / (r * 2.5)) * (1.0 - smoothstep(r * 4.0, r * 6.0, dist)) * clamp(glow, 0.0, 1.0) * 0.7;
		float fk = clamp(flicker, 0.0, 1.0);
		float wave = 0.5 + 0.5 * sin(t * (6.0 + 9.0 * h.w) + h.y * 40.0) * sin(t * (2.3 + 3.1 * h.z) + h.x * 17.0);
		float bright = (1.0 - fk * wave) * (0.45 + 0.55 * depth);
		vec3 hot = mix(vec3(1.0, 0.85, 0.45), vec3(0.95, 0.22, 0.05), h.w);
		vec3 col = mix(colour.rgb, hot, clamp(colour_spread, 0.0, 1.0));
		acc += col * (core * 1.3 + halo) * bright;
	}
	acc *= colour.a;
	float peak = max(acc.r, max(acc.g, acc.b));
	vec3 gen = peak > 0.0001 ? acc / peak : colour.rgb;
	COLOR = mix_in(rgb, a, gen, clamp(peak, 0.0, 1.0), blend, strength);
}
