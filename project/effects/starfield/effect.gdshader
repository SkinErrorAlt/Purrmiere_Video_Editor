shader_type canvas_item;
render_mode blend_disabled;

uniform int layers : hint_range(3, 5) = 4;
uniform float density : hint_range(0.0, 1.0) = 0.4;
uniform float size : hint_range(0.5, 20.0) = 2.0;
uniform float twinkle : hint_range(0.0, 1.0) = 0.3;
uniform float warp : hint_range(0.0, 1.0) = 0.0;
uniform float speed : hint_range(0.0, 10.0) = 0.5;
uniform float angle : hint_range(-180.0, 180.0) = 180.0;
uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float colour_spread : hint_range(0.0, 1.0) = 0.3;
uniform int seed : hint_range(0, 9999) = 0;
uniform int blend : hint_range(0, 6) = 2;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 hash32(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yzz) * p3.zyx);
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
	vec2 pos = (UV - 0.5) * sz;
	float rlen = length(pos);
	vec2 rdir = rlen > 0.0001 ? pos / rlen : vec2(1.0, 0.0);
	vec2 side_dir = vec2(-rdir.y, rdir.x);
	float cellpx = 56.0 * ps;
	int nl = clamp(layers, 1, 5);
	float t = clip_time * speed;
	float wp = clamp(warp, 0.0, 1.0);
	float dens = clamp(density, 0.0, 1.0);
	float rad = radians(angle);
	vec2 drift = mod(vec2(cos(rad), sin(rad)) * t * (1.0 - wp) * 1.5, vec2(1024.0));
	vec2 skey = floor(hash22(vec2(float(seed) * 0.7123 + 3.1, 11.7)) * 997.0);
	vec3 acc = vec3(0.0);
	float lum = 0.0;
	for (int li = 0; li < 5; li++) {
		if (li >= nl) { break; }
		float fl = float(li);
		float travel = (fl + 0.5) / float(nl) + t * wp * 0.12;
		float phase = fract(travel);
		float cycle = mod(floor(travel), 512.0);
		float zoom = exp2(phase * 4.0 - 2.0);
		float fade = smoothstep(0.0, 0.25, phase) * (1.0 - smoothstep(0.8, 1.0, phase));
		float cz = zoom * cellpx;
		vec2 lay = hash22(vec2(fl * 7.31 + cycle * 1.37, 5.3) + skey) * 64.0;
		vec2 q = pos / cz + lay + drift;
		vec2 base = floor(q);
		vec2 f = q - base;
		float r_px = min(size * ps * mix(0.35, 1.3, phase), 0.2 * cz);
		float r_eff = max(r_px, 0.8);
		float halo_r = min(r_eff * 3.0 + 1.0, 0.6 * cz);
		float dim = clamp(r_px / 0.8, 0.15, 1.0);
		float tail_len = min(rlen * speed * wp * 0.35, 0.6 * cz);
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 o = vec2(float(i), float(j));
				vec2 cid = mod(base + o, vec2(1024.0)) + vec2(fl * 1031.0, 0.0) + skey;
				vec3 h = hash32(cid);
				if (h.x < dens) {
					vec2 h2 = hash22(cid + vec2(41.7, 13.9));
					vec2 star = o + 0.2 + 0.6 * h.yz;
					vec2 dpx = (f - star) * cz;
					float along = dot(dpx, rdir);
					float across = dot(dpx, side_dir);
					float along_c = along - clamp(along, -tail_len, 0.0);
					float dist = length(vec2(along_c, across));
					float tail_fade = 1.0 - 0.7 * clamp(-along / max(tail_len, 0.0001), 0.0, 1.0);
					float core = 1.0 - smoothstep(r_eff * 0.5, r_eff + 0.6, dist);
					float halo = 0.25 * (1.0 - smoothstep(0.0, halo_r, dist));
					float tw = 1.0 - clamp(twinkle, 0.0, 1.0) * (0.5 + 0.5 * sin(clip_time * (1.5 + 4.0 * h2.x) + 6.2831853 * h2.y));
					float bright = 0.5 + 0.5 * clamp(h.x / max(dens, 0.0001), 0.0, 1.0);
					float b = (core + halo) * dim * tail_fade * tw * bright * fade;
					vec3 tint = mix(vec3(1.0), mix(vec3(0.65, 0.78, 1.0), vec3(1.0, 0.82, 0.55), h2.x), clamp(colour_spread, 0.0, 1.0));
					acc += tint * b;
					lum += b;
				}
			}
		}
	}
	vec3 gen = colour.rgb * acc / max(lum, 0.0001);
	float cov = clamp(lum, 0.0, 1.0) * colour.a;
	COLOR = mix_in(rgb, a, gen, cov, blend, strength);
}
