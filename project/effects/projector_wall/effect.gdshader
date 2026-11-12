shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 top_left = vec2(0.07, 0.06);
uniform vec2 top_right = vec2(0.93, 0.07);
uniform vec2 bottom_right = vec2(0.885, 0.9);
uniform vec2 bottom_left = vec2(0.115, 0.895);
uniform float brightness : hint_range(0.0, 3.0) = 1.15;
uniform float hotspot : hint_range(0.0, 1.0) = 0.45;
uniform float focus : hint_range(0.0, 20.0) = 1.5;
uniform float fringe : hint_range(0.0, 12.0) = 2.0;
uniform float black_level : hint_range(0.0, 0.3) = 0.04;
uniform float ambient : hint_range(0.0, 1.0) = 0.16;
uniform vec4 wall_colour : source_color = vec4(0.86, 0.84, 0.8, 1.0);
uniform float wall_texture : hint_range(0.0, 1.0) = 0.55;
uniform float texture_size : hint_range(0.3, 4.0) = 1.0;
uniform float spill : hint_range(0.0, 1.0) = 0.35;
uniform float dust : hint_range(0.0, 1.0) = 0.3;
uniform float dust_speed : hint_range(0.0, 3.0) = 0.4;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size;
uniform float px_scale;
uniform float time;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float wall_height(vec2 p) {
	float s = max(texture_size * px_scale, 0.05);
	float peel = vnoise(p / (5.0 * s)) * 0.55 + vnoise(p / (2.4 * s) + 17.0) * 0.3 + vnoise(p / (1.2 * s) + 5.0) * 0.15;
	float knock = smoothstep(0.42, 0.9, vnoise(p / (26.0 * s) + 41.0) * 0.7 + vnoise(p / (9.0 * s) + 3.0) * 0.3);
	return peel * 0.9 + knock * 0.45;
}

mat3 square_to_quad(vec2 p0, vec2 p1, vec2 p2, vec2 p3) {
	vec2 d1 = p1 - p2;
	vec2 d2 = p3 - p2;
	vec2 sm = p0 - p1 + p2 - p3;
	float den = d1.x * d2.y - d2.x * d1.y;
	float g = 0.0;
	float h = 0.0;
	if (abs(den) > 0.0000001) {
		g = (sm.x * d2.y - d2.x * sm.y) / den;
		h = (d1.x * sm.y - sm.x * d1.y) / den;
	}
	float a = p1.x - p0.x + g * p1.x;
	float b = p3.x - p0.x + h * p3.x;
	float d = p1.y - p0.y + g * p1.y;
	float e = p3.y - p0.y + h * p3.y;
	return mat3(vec3(a, d, g), vec3(b, e, h), vec3(p0.x, p0.y, 1.0));
}

vec3 to_lin(vec3 c) {
	return pow(max(c, vec3(0.0)), vec3(2.2));
}

vec3 sample_lens(sampler2D tex, vec2 st, vec2 dir, vec2 blur, vec2 ca) {
	vec3 acc = vec3(0.0);
	for (int i = 0; i < 9; i++) {
		vec2 o = vec2(0.0);
		if (i > 0) {
			float ang = float(i) * 0.785398 + 0.39;
			o = vec2(cos(ang), sin(ang)) * blur * (i % 2 == 0 ? 1.0 : 0.6);
		}
		vec2 q = st + o;
		vec4 r = texture(tex, clamp(q + dir * ca.x, vec2(0.0), vec2(1.0)));
		vec4 g = texture(tex, clamp(q, vec2(0.0), vec2(1.0)));
		vec4 b = texture(tex, clamp(q - dir * ca.y, vec2(0.0), vec2(1.0)));
		acc += vec3(r.r, g.g, b.b);
	}
	return acc / 9.0;
}

void fragment() {
	vec4 here = texture(TEXTURE, UV);
	float a = here.a;
	vec2 size = max(tex_size, vec2(1.0));
	vec2 p = UV * size;
	float s = max(px_scale, 0.05);
	mat3 m = square_to_quad(top_left, top_right, bottom_right, bottom_left);
	mat3 inv = inverse(m);
	vec3 hs = inv * vec3(UV, 1.0);
	vec2 st = hs.xy / hs.z;
	float wc = (m * vec3(0.5, 0.5, 1.0)).z;
	float wp = (m * vec3(st, 1.0)).z;
	float stretch = pow(clamp(wp / wc, 0.2, 5.0), 3.0);
	float quad_w = max(length(top_right - top_left), 0.05);
	float edge_soft = max(focus * s, 0.7) / max(size.x * quad_w, 1.0);
	vec2 e = smoothstep(vec2(-edge_soft), vec2(edge_soft), st) * smoothstep(vec2(1.0 + edge_soft), vec2(1.0 - edge_soft), st);
	float inside = e.x * e.y;
	if (hs.z <= 0.0) {
		inside = 0.0;
	}
	float aspect = size.x / size.y;
	vec2 rc = (st - 0.5) * vec2(aspect, 1.0);
	float r2 = dot(rc, rc) / (0.25 * aspect * aspect + 0.25);
	float fall = mix(1.0, 1.0 / pow(1.0 + 1.6 * r2, 2.0), hotspot);
	vec2 px_st = vec2(1.0) / (size * quad_w);
	vec2 blur = px_st * focus * s * (0.25 + 1.5 * r2);
	vec2 ca = vec2(fringe * s * r2);
	vec2 dir = normalize(rc + vec2(0.00001)) * px_st * sqrt(r2);
	vec3 proj = to_lin(sample_lens(TEXTURE, st, dir, blur, ca));
	float proj_alpha = texture(TEXTURE, clamp(st, vec2(0.0), vec2(1.0))).a;
	vec3 beam = (proj + vec3(black_level) * proj_alpha) * brightness * fall * stretch * inside;
	vec2 out_d = max(abs(st - 0.5) - 0.5, vec2(0.0));
	float od = length(out_d * vec2(aspect, 1.0));
	float glow_out = spill * (1.0 - inside) * (exp(-od * 60.0) * 0.05 + exp(-od * 9.0) * 0.02) * brightness;
	float h0 = wall_height(p);
	float hx = wall_height(p + vec2(s, 0.0));
	float hy = wall_height(p + vec2(0.0, s));
	float bump = wall_texture * 0.8;
	vec3 n = normalize(vec3((h0 - hx) * bump, (h0 - hy) * bump, 0.25));
	vec3 l_proj = normalize(vec3((0.5 - st.x) * 0.3, 0.32 + (0.5 - st.y) * 0.2, 1.0));
	vec3 l_room = normalize(vec3(0.35, -0.7, 0.6));
	float shade_proj = clamp(dot(n, l_proj), 0.0, 1.0) / max(l_proj.z, 0.01);
	float shade_room = clamp(dot(n, l_room), 0.0, 1.0) / max(l_room.z, 0.01);
	float blot = vnoise(p / (180.0 * s) + 9.0) * 0.6 + vnoise(p / (60.0 * s) + 2.0) * 0.4;
	vec3 albedo = to_lin(wall_colour.rgb) * (1.0 + wall_texture * 0.1 * (blot - 0.5));
	float room = ambient * ambient * 0.6 * (0.75 + 0.25 * (1.0 - UV.y));
	vec3 light = beam * shade_proj + vec3(room * shade_room + glow_out * shade_proj);
	vec3 lin = albedo * light;
	if (dust > 0.0) {
		vec3 motes = vec3(0.0);
		for (int layer = 0; layer < 3; layer++) {
			float fl = float(layer);
			float cellsz = (70.0 + fl * 45.0) * s;
			vec2 drift = vec2(0.35 + fl * 0.2, -0.55 - fl * 0.15) * time * dust_speed * (24.0 + fl * 12.0) * s;
			vec2 q = (p + drift) / cellsz;
			for (int k = 0; k < 4; k++) {
				vec2 cid = floor(q - 0.5) + vec2(float(k % 2), float(k / 2));
				vec2 rnd = hash22(cid + float(seed) * 1.7 + fl * 31.0);
				float present = step(1.0 - dust * 0.6, hash12(cid * 1.3 + fl * 7.0 + float(seed)));
				vec2 wob = vec2(sin(time * dust_speed * 1.3 + rnd.x * 6.28), cos(time * dust_speed * 1.1 + rnd.y * 6.28)) * 0.12;
				vec2 mp = (cid + rnd + wob) * cellsz - drift;
				float rad = (1.2 + fl * 1.6 + rnd.y * 1.5) * s;
				float dd = length(p - mp);
				float disc = 1.0 - smoothstep(rad * 0.6, rad, dd);
				float ring = fl > 0.5 ? (0.6 + 0.4 * smoothstep(rad * 0.4, rad * 0.9, dd)) : 1.0;
				vec3 hm = inv * vec3(mp / size, 1.0);
				vec2 mst = hm.xy / hm.z;
				float in_beam = step(0.0, mst.x) * step(mst.x, 1.0) * step(0.0, mst.y) * step(mst.y, 1.0) * step(0.0, hm.z);
				vec3 lit = to_lin(texture(TEXTURE, clamp(mst, vec2(0.0), vec2(1.0))).rgb) * brightness + vec3(black_level);
				motes += lit * disc * ring * present * in_beam * (0.5 - fl * 0.12);
			}
		}
		lin += motes * dust * 2.5;
	}
	vec3 outc = pow(max(lin, vec3(0.0)), vec3(1.0 / 2.2));
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
