shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform float angle : hint_range(-180.0, 180.0) = -20.0;
uniform float speck_size : hint_range(1.0, 40.0) = 4.0;
uniform float drift : hint_range(0.0, 1.0) = 0.35;
uniform float sweep : hint_range(0.0, 1.0) = 0.9;
uniform float turbulence : hint_range(0.0, 1.0) = 0.5;
uniform vec4 edge_colour : source_color = vec4(1.0, 0.55, 0.2, 1.0);
uniform float edge_glow : hint_range(0.0, 1.0) = 0.5;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

const float LIFE = 0.22;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 w = mod(i, 512.0);
	return mix(mix(hash12(w), hash12(w + vec2(1.0, 0.0)), f.x), mix(hash12(w + vec2(0.0, 1.0)), hash12(w + vec2(1.0, 1.0)), f.x), f.y);
}

float depart(vec2 cell, vec2 sz, float s, vec2 wind, float span, vec2 sk) {
	vec2 cc = (cell + 0.5) * s;
	float proj = dot(cc - sz * 0.5, wind) / span;
	float sweep_pos = clamp(0.5 - 0.5 * proj, 0.0, 1.0);
	float front = value_noise(cc / (s * 30.0 + 60.0) + sk) * 0.65 + value_noise(cc / (s * 6.0 + 12.0) + sk.yx) * 0.35;
	float rn = hash12(mod(cell, 2048.0) + sk);
	float sw = clamp(sweep, 0.0, 1.0);
	float ordered = sweep_pos * 0.86 + front * 0.14;
	return clamp(mix(rn, ordered, sw) * 0.96 + rn * 0.04, 0.0, 1.0);
}

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 pix = UV * sz;
	vec2 sk = vec2(mod(float(seed), 997.0) * 0.771 + 2.0, mod(float(seed), 991.0) * 0.353 + 6.0);
	float ang = radians(angle);
	vec2 wind = vec2(cos(ang), sin(ang));
	vec2 side = vec2(-wind.y, wind.x);
	float span = max(0.5 * (abs(wind.x) * sz.x + abs(wind.y) * sz.y), 1.0);
	float s = max(speck_size * ps, 1.0);
	float pr = clamp(progress, 0.0, 1.0) * (1.0 + LIFE);
	float travel = clamp(drift, 0.0, 1.0) * length(sz) * 0.6;
	vec2 own_cell = floor(pix / s);
	float own_age = (pr - depart(own_cell, sz, s, wind, span, sk)) / LIFE;
	vec4 base = vec4(0.0);
	if (own_age <= 0.0) {
		base = texture(TEXTURE, UV);
		float g = clamp(1.0 + own_age / 0.35, 0.0, 1.0) * step(0.0001, pr) * clamp(edge_glow, 0.0, 1.0) * edge_colour.a;
		base.rgb = mix(base.rgb, edge_colour.rgb * base.a, g * g * 0.85);
	}
	vec4 speck = vec4(0.0);
	if (travel > 0.5 && pr > 0.0 && own_age > 0.0) {
		float wave = value_noise(pix / (90.0 * ps) + sk + vec2(pr * 2.0, 0.0)) - 0.5;
		vec2 pw = pix - side * wave * clamp(turbulence, 0.0, 1.0) * travel * 0.3;
		for (int k = 0; k <= 40; k++) {
			float fk = float(k);
			float back = s * 0.9 * fk * (1.0 + 0.08 * fk);
			if (back > travel * 1.5 + s || speck.a > 0.97) {
				break;
			}
			vec2 cell = floor((pw - wind * back) / s);
			float age = (pr - depart(cell, sz, s, wind, span, sk)) / LIFE;
			if (age <= 0.0 || age >= 1.0) {
				continue;
			}
			float spd = 0.6 + 0.8 * hash12(mod(cell, 2048.0) + sk + 31.0);
			vec2 cc = (cell + 0.5) * s;
			vec2 rel = pw - cc;
			float along = dot(rel, wind);
			float across = abs(dot(rel, side));
			float moved = travel * spd * pow(age, 0.85);
			float hs = s * 0.5 * (1.0 - 0.5 * age);
			float trail_len = min(moved, s * 7.0);
			if (across < hs && along <= moved + hs && along >= moved - trail_len - hs) {
				float head = clamp((along - (moved - trail_len)) / max(trail_len, 0.001), 0.0, 1.0);
				vec4 src = texture(TEXTURE, clamp(cc / sz, vec2(0.0), vec2(1.0)));
				float glow_mix = (1.0 - age) * clamp(edge_glow, 0.0, 1.0) * 0.7 * edge_colour.a;
				src.rgb = mix(src.rgb, edge_colour.rgb * src.a, glow_mix);
				float fade = pow(1.0 - age, 1.1) * mix(0.35, 1.0, head * head);
				speck += src * fade * (1.0 - speck.a);
			}
		}
	}
	COLOR = speck + base * (1.0 - speck.a);
}
