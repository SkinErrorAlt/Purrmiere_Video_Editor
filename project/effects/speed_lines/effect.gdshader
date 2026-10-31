shader_type canvas_item;
render_mode blend_disabled;

uniform int style : hint_range(0, 1) = 0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform float clear_middle : hint_range(0.0, 1.0) = 0.45;
uniform float count : hint_range(10.0, 600.0) = 150.0;
uniform float thickness : hint_range(0.1, 6.0) = 1.0;
uniform float length_spread : hint_range(0.0, 1.0) = 0.6;
uniform float rate : hint_range(0.0, 30.0) = 12.0;
uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.9;
uniform int seed : hint_range(0, 9999) = 0;
uniform int blend : hint_range(0, 6) = 6;
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

float radial_lines(vec2 d, float reach, float n, float ps, vec2 sk) {
	float r = length(d);
	float ang = r > 0.001 ? atan(d.y, d.x) : 0.0;
	float x = (ang / 6.2831853 + 0.5) * n;
	float k0 = floor(x);
	float clear_r = clamp(clear_middle, 0.0, 1.0) * reach * 0.8;
	float cov = 0.0;
	for (int j = -1; j <= 1; j++) {
		float k = k0 + float(j);
		float kw = mod(k, n);
		vec4 h = hash42(vec2(kw, 7.0) + sk);
		if (h.w < 0.2) {
			continue;
		}
		float ca = k + 0.5 + (h.x - 0.5) * 0.8;
		float dang = (x - ca) / n * 6.2831853;
		float r0 = clear_r * (1.0 + h.y * clamp(length_spread, 0.0, 1.0) * 1.1) + 2.0 * ps;
		if (r <= r0) {
			continue;
		}
		float grow = clamp((r - r0) / max(reach * 0.4, 1.0), 0.0, 1.0);
		float hw = max(thickness, 0.0) * ps * (0.7 + 3.3 * h.z * h.z) * sqrt(grow);
		float dist = abs(dang) * r;
		float line = 1.0 - smoothstep(hw - 0.6, hw + 0.6, dist);
		line *= clamp(hw * 2.0, 0.0, 1.0);
		cov = max(cov, line);
	}
	return cov;
}

float straight_lines(vec2 d, vec2 size, float n, float ps, vec2 sk) {
	float ang = radians(angle);
	vec2 dir = vec2(cos(ang), sin(ang));
	vec2 nrm = vec2(-dir.y, dir.x);
	float u = dot(d, dir);
	float v = dot(d, nrm);
	float diag = length(size);
	float spacing = max(diag * 1.2 / n, 1.0);
	float row = floor(v / spacing);
	float e = length(d / max(size * 0.5, vec2(1.0)));
	float cov = 0.0;
	for (int j = -1; j <= 1; j++) {
		float k = row + float(j);
		vec4 h = hash42(vec2(mod(k, 2048.0), 3.0) + sk);
		if (h.w < 0.3) {
			continue;
		}
		float vk = (k + 0.5 + (h.x - 0.5) * 0.7) * spacing;
		float seg = diag * (0.12 + 0.45 * h.y);
		float uk = (h.z - 0.5) * diag * 1.1;
		float t = (u - uk) / seg + 0.5;
		if (t <= 0.0 || t >= 1.0) {
			continue;
		}
		float hw = max(thickness, 0.0) * ps * (0.5 + 1.8 * h.z * h.z) * sin(3.14159265 * t);
		float dist = abs(v - vk);
		float line = 1.0 - smoothstep(hw - 0.6, hw + 0.6, dist);
		line *= clamp(hw * 2.0, 0.0, 1.0);
		float keep_out = clamp(clear_middle, 0.0, 1.0) * (0.7 + 0.6 * h.y * clamp(length_spread, 0.0, 1.0));
		line *= smoothstep(keep_out, keep_out + 0.15, e);
		cov = max(cov, line);
	}
	return cov;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 size = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float frame = rate > 0.0 ? mod(floor(clip_time * rate), 4096.0) : 0.0;
	vec2 sk = vec2(mod(float(seed), 997.0) * 1.37 + 11.0, frame * 1.113 + 5.0);
	vec2 cpx = centre * size;
	vec2 d = UV * size - cpx;
	float n = max(floor(count), 1.0);
	float cov = 0.0;
	if (style == 0) {
		float reach = length(max(cpx, size - cpx));
		cov = radial_lines(d, reach, n, ps, sk);
	} else {
		cov = straight_lines(d, size, n, ps, sk);
	}
	cov *= clamp(opacity, 0.0, 1.0) * colour.a;
	COLOR = mix_in(rgb, a, colour.rgb, cov, blend, strength);
}
