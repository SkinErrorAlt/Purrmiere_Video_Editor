shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/slime_mould/sim.gdshaderinc"

uniform sampler2D s_tex : filter_nearest, repeat_disable;
uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float clip_time = 0.0;
uniform float start_time : hint_range(0.0, 30.0) = 0.0;
uniform float thickness : hint_range(0.0, 1.0) = 0.5;
uniform float explore : hint_range(0.0, 1.0) = 0.6;
uniform float retract : hint_range(0.2, 20.0) = 4.0;
uniform vec4 colour : source_color = vec4(0.98, 0.8, 0.06, 1.0);
uniform int seed : hint_range(0, 9999) = 0;

const float T_RANGE = 120.0;

float veins(vec2 p, float sd) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = sim_hash2(i + g + sd) * 0.9 + 0.05;
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return d2 - d1;
}

void fragment() {
	vec2 tsz = vec2(textureSize(effect_tex, 0));
	vec2 asp = vec2(tsz.x / max(tsz.y, 1.0), 1.0);
	vec2 q = UV * asp;
	float sd = float(seed) * 1.731;
	float front = clip_time - start_time;

	float ts = sim_field(s_tex, UV) * T_RANGE;
	float wob = ((sim_fbm(q * 6.0 + sd, 4) - 0.5) * 1.0 + (sim_fbm(q * 22.0 + sd, 3) - 0.5) * 0.35) * clamp(ts * 0.5, 0.0, 1.0);
	float since = front - ts + wob;

	vec4 src = texture(effect_tex, UV);
	float alpha = src.a;
	vec3 pic = src.rgb / max(alpha, 0.0001);
	float l = sim_luma(pic);

	vec4 tr = texture(TEXTURE, UV);
	float d = tr.r / 20.0;
	float count = tr.g * 12.0;
	float rad = (0.0022 + 0.0065 * thickness) * sqrt(max(count, 1.0)) * (0.35 + 0.65 * tr.b);
	rad *= 0.85 + 0.3 * sim_noise(q * 30.0 + sd);
	rad = min(rad, 0.03);
	float tube = (1.0 - smoothstep(rad * 0.75, rad * 1.1, d)) * step(0.001, tr.b);
	float core = clamp(1.0 - d / max(rad, 1e-4), 0.0, 1.0) * step(0.001, tr.b);

	float reached = smoothstep(-0.1, 0.1, since);
	vec2 wq = q + vec2(sim_fbm(q * 9.0 + sd + 2.0, 3), sim_fbm(q * 9.0 + sd + 7.0, 3)) * 0.06;
	float fine = 1.0 - smoothstep(0.03, 0.12, veins(wq * 85.0, sd));
	float mid = 1.0 - smoothstep(0.02, 0.07, veins(wq * 34.0, sd + 5.0));
	float wide = 1.0 - smoothstep(0.012, 0.04, veins(wq * 13.0, sd + 9.0));
	float sheet = reached * (1.0 - smoothstep(0.0, 0.35, since));
	float fan = reached * (1.0 - smoothstep(0.25, 1.4, since));
	float living = 1.0 - smoothstep(retract * 0.5, retract, since);
	float net = max(fan * max(fine, mid), reached * living * max(mid * (1.0 - smoothstep(0.6, retract * 0.7, since)), wide));
	float explored = max(sheet * (0.75 + 0.25 * fine), net * 0.85) * explore;
	float track = reached * (1.0 - living) * 0.25 * explore;

	float food = smoothstep(0.62, 0.9, l) * smoothstep(0.0, 1.2, since) * (1.0 - smoothstep(0.0, 0.003, d - rad * 3.0));
	food = max(food, smoothstep(0.75, 0.95, l) * reached * 0.7);

	float cover = clamp(max(max(tube, explored), food * 0.9), 0.0, 1.0);
	float thick = max(core * (0.55 + 0.45 * thickness), max(explored * 0.3, food * 0.45));

	float pulse = 0.86 + 0.14 * sin(ts * 6.0 - front * 3.0);
	vec3 base = colour.rgb;
	vec3 deep = base * vec3(0.9, 0.58, 0.22);
	vec3 mould = mix(base * 1.06, deep, smoothstep(0.2, 1.0, thick) * 0.75);
	vec3 tube_col = mix(deep * 0.85, base * 1.12, sqrt(core)) * pulse;
	mould = mix(mould, tube_col, tube);
	mould *= 0.9 + 0.2 * sim_noise(q * 260.0 + sd) * (0.5 + 0.5 * sim_noise(q * 60.0 - sd));
	float hx = dFdx(thick);
	float hy = dFdy(thick);
	vec3 n = normalize(vec3(-hx * 5.0, -hy * 5.0, 1.0));
	float spec = pow(max(dot(n, normalize(vec3(-0.4, -0.6, 0.7))), 0.0), 16.0);
	mould += vec3(1.0, 0.97, 0.88) * spec * 0.3 * cover;

	vec3 col = pic;
	col = mix(col, col * (base * 0.7 + 0.3), track);
	col *= 1.0 - 0.3 * smoothstep(0.0, 0.6, cover);
	float opa = cover * mix(0.5, 0.97, clamp(thick * 1.8, 0.0, 1.0));
	col = mix(col, mould, opa);
	col = clamp(col, 0.0, 1.0);
	COLOR = vec4(col * alpha, alpha);
}
