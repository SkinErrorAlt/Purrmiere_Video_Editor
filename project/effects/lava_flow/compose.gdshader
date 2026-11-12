shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/lava_flow/sim.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D grid_tex : filter_nearest, repeat_disable;
uniform float clip_time = 0.0;
uniform float start_time : hint_range(0.0, 30.0) = 0.0;
uniform float cooling : hint_range(1.0, 60.0) = 12.0;
uniform float crust : hint_range(0.0, 1.0) = 0.6;
uniform float glow : hint_range(0.0, 1.0) = 0.7;
uniform float steam : hint_range(0.0, 1.0) = 0.5;
uniform int seed : hint_range(0, 9999) = 0;

const float T_RANGE = 120.0;

float front_now(float t) {
	if (t <= 0.0) {
		return -1.0;
	}
	return cooling * log(1.0 + t / cooling);
}

float covered_at(float tt) {
	return cooling * (exp(min(tt, 60.0) / cooling) - 1.0);
}

float cells(vec2 p, float sd) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = sim_hash2(i + g + sd) * 0.85 + 0.075;
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

vec3 molten(float x) {
	x = clamp(x, 0.0, 1.0);
	return vec3(0.45 + 0.55 * smoothstep(0.0, 0.5, x), 0.04 + 0.62 * smoothstep(0.35, 0.95, x), 0.01 + 0.3 * smoothstep(0.85, 1.0, x));
}

void fragment() {
	vec2 tsz = vec2(textureSize(effect_tex, 0));
	vec2 asp = vec2(tsz.x / max(tsz.y, 1.0), 1.0);
	vec2 q = UV * asp;
	float sd = float(seed) * 0.613;
	float tl = clip_time - start_time;
	float front = front_now(tl);

	float tt = sim_field(grid_tex, UV) * T_RANGE;
	float e = 0.004;
	float tx = sim_field(grid_tex, UV + vec2(e / asp.x, 0.0)) * T_RANGE - tt;
	float ty = sim_field(grid_tex, UV + vec2(0.0, e)) * T_RANGE - tt;
	vec2 flow = vec2(tx, ty);
	float fl = length(flow);
	vec2 dir = fl > 1e-5 ? flow / fl : vec2(0.0, 1.0);
	vec2 side = vec2(-dir.y, dir.x);

	float lobe = sim_fbm(q * 14.0 + sd, 4) * 1.1 * clamp(tt * 0.4, 0.0, 1.0);
	float ahead = front - (tt + lobe);
	float on = smoothstep(-0.02, 0.06, ahead);
	float since = tl - covered_at(tt + lobe);
	float heat = exp(-max(since, 0.0) / (0.8 + 3.0 * (1.0 - crust)));
	heat = max(heat, smoothstep(0.5, 0.0, ahead) * on);

	vec4 src = texture(effect_tex, UV);
	float alpha = src.a;
	vec3 pic = src.rgb / max(alpha, 0.0001);

	float creep = tl * 0.04;
	vec2 fq = vec2(dot(q, side), dot(q, dir)) - vec2(0.0, creep);
	float ropes = sim_fbm(vec2(fq.x * 30.0, fq.y * 9.0) + sd, 4);
	float plates = cells(q * 22.0 + dir * creep * 3.0 + vec2(ropes * 0.4), sd);
	float crack = 1.0 - smoothstep(0.02, 0.09 + 0.12 * heat, plates);
	float skin = smoothstep(0.15, 0.85, 1.0 - heat + (ropes - 0.5) * 0.6);
	skin = mix(skin, 1.0, crust * smoothstep(0.0, 6.0, since));
	vec3 basalt = vec3(0.055, 0.048, 0.046) * (0.7 + 0.7 * ropes);
	float sheen = pow(clamp(ropes * 1.4 - 0.2, 0.0, 1.0), 6.0) * 0.25;
	basalt += vec3(0.5, 0.52, 0.56) * sheen * (1.0 - heat * 0.5);
	vec3 hot = molten(0.3 + 0.6 * heat + 0.25 * (ropes - 0.5));
	vec3 lava = mix(hot, basalt, skin * (1.0 - crack * 0.85));
	float glow_crack = crack * max(heat, 0.1 * exp(-max(since, 0.0) / 30.0)) * glow;
	lava = mix(lava, molten(0.35 + 0.5 * heat), glow_crack);
	float rim = smoothstep(0.25, 0.0, ahead) * on;
	lava = mix(lava, molten(0.85), rim * 0.6 * glow);
	float bump = ropes + plates * 0.5;
	float lit = clamp(0.5 - dFdy(bump) * 18.0 - dFdx(bump) * 8.0, 0.0, 1.0);
	lava *= 0.8 + 0.4 * lit;

	vec3 col = pic;
	float scorch = (1.0 - on) * smoothstep(-0.8, 0.0, ahead);
	col = mix(col, col * vec3(0.75, 0.55, 0.4), scorch * 0.6);
	float near = 0.0;
	for (int k = 0; k < 8; k++) {
		float a = float(k) * 0.785398 + 0.2;
		vec2 p = UV + vec2(cos(a) / asp.x, sin(a)) * 0.06;
		float t2 = sim_field(grid_tex, p) * T_RANGE;
		float s2 = tl - covered_at(t2);
		near += step(t2, front) * exp(-max(s2, 0.0) / 6.0);
	}
	near /= 8.0;
	col = 1.0 - (1.0 - col) * (1.0 - vec3(1.0, 0.42, 0.12) * near * 0.45 * glow * (1.0 - on));
	col = mix(col, lava, on);

	float fog = 0.0;
	for (int j = 1; j <= 8; j++) {
		float h = float(j) * 0.04;
		vec2 p = UV + vec2((sim_noise(vec2(float(j), tl * 0.3 + sd)) - 0.5) * 0.04, h);
		float t2 = sim_field(grid_tex, p) * T_RANGE;
		float s2 = tl - covered_at(t2);
		fog += step(t2, front) * exp(-max(s2, 0.0) / 3.0) * (1.0 - float(j) / 10.0);
	}
	float bill = sim_fbm(vec2(q.x * 5.0, q.y * 4.0 + tl * 0.45) + sd, 5);
	fog = clamp(fog * 0.22 * (0.2 + 1.5 * bill), 0.0, 1.0) * steam;
	col = mix(col, vec3(0.62, 0.6, 0.6) * (0.75 + 0.35 * bill) + vec3(0.25, 0.08, 0.0) * near, fog * 0.6);
	col = clamp(col, 0.0, 1.0);
	COLOR = vec4(col * alpha, alpha);
}
