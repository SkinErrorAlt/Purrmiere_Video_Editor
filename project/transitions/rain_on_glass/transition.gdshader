shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float drops : hint_range(0.0, 1.0) = 0.6;
uniform float drop_size : hint_range(0.3, 2.0) = 1.0;
uniform float run_speed : hint_range(0.0, 1.0) = 0.5;
uniform float fog : hint_range(0.0, 1.0) = 0.6;
uniform float refraction : hint_range(0.0, 1.0) = 0.6;
uniform float clear_point : hint_range(0.3, 0.9) = 0.6;

struct Glass {
	vec2 refr;
	float bead;
	float edge;
	float hi;
	float clear;
};

Glass glass_at(vec2 uv, float p) {
	Glass g;
	g.refr = vec2(0.0);
	g.bead = 0.0;
	g.edge = 0.0;
	g.hi = 0.0;
	g.clear = 0.0;
	float ar = tr_ratio();
	for (int l = 0; l < 2; l++) {
		float scale = (l == 0 ? 8.0 : 15.0) * drop_size;
		vec2 gg = vec2(uv.x * ar, uv.y) * scale + float(l) * 17.3 + floor(seed);
		vec2 id = floor(gg);
		vec2 f = fract(gg) - 0.5;
		vec2 h = tr_hash2(id);
		vec2 h2 = tr_hash2(id + 4.7);
		if (h.x > 0.3 + drops * 0.45) {
			continue;
		}
		float r = 0.13 + 0.26 * h.y;
		float run = step(0.6, h2.x);
		float slide = run * p * run_speed * (0.7 + 0.9 * h.y);
		vec2 c = vec2((h2.x - 0.5) * 0.5, (h2.y - 0.5) * 0.5 + slide);
		vec2 fd = f - c;
		float d = length(fd);
		float inside = smoothstep(r, r * 0.55, d);
		g.refr += (c - f) * inside * (0.5 + refraction * 0.9) / scale;
		g.bead = max(g.bead, inside);
		g.edge = max(g.edge, inside * smoothstep(r * 0.5, r, d));
		vec2 hp = c + vec2(-0.32, -0.32) * r;
		g.hi = max(g.hi, smoothstep(r * 0.26, 0.0, length(f - hp)) * inside);
		float along = (c.y - f.y) / max(slide, 0.0001);
		float trail = run * smoothstep(0.08 * drop_size, 0.0, abs(fd.x)) * step(0.0, along) * step(along, 1.0) * (0.5 + 0.5 * h2.y);
		g.clear = max(g.clear, max(inside, trail * 0.85));
	}
	return g;
}

void fragment() {
	vec2 uv = UV;
	float p = progress;
	float cp = clamp(clear_point, 0.3, 0.9);
	float swap = tr_ease(clamp(p / cp, 0.0, 1.0), 0);

	Glass g = glass_at(uv, p);
	vec2 suv = clamp(uv + g.refr, vec2(0.0), vec2(1.0));
	vec3 base = mix(from_clamped(suv).rgb, to_clamped(suv).rgb, swap);

	float fog_amt = fog * (1.0 - smoothstep(cp - 0.1, 1.0, p));
	float local_fog = clamp(fog_amt * (1.0 - g.clear * 0.95), 0.0, 1.0);
	vec3 fogged = mix(base, vec3(0.78, 0.81, 0.86), 0.72);
	vec3 col = mix(base, fogged, local_fog);

	col *= 1.0 - g.edge * 0.35;
	col += vec3(1.0, 1.0, 0.98) * g.hi * 0.7 * (1.0 - swap * 0.3);

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
