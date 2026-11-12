shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/wildfire/sim.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float clip_time = 0.0;
uniform float start_time : hint_range(0.0, 30.0) = 0.0;
uniform float flames : hint_range(0.0, 1.0) = 0.8;
uniform float smoke : hint_range(0.0, 1.0) = 0.6;
uniform float charring : hint_range(0.0, 1.0) = 0.85;
uniform float embers : hint_range(0.0, 1.0) = 0.7;
uniform float wind : hint_range(-1.0, 1.0) = 0.2;
uniform int seed : hint_range(0, 9999) = 0;

const float T_RANGE = 120.0;

#define arrival(uv) (sim_field(TEXTURE, uv) * T_RANGE)
#define fuel_at(uv) (texture(TEXTURE, uv).b)

float burn_len(float fuel) {
	return 0.35 + 0.9 * fuel;
}

float burning(float age, float fuel) {
	float dur = burn_len(fuel);
	return smoothstep(0.0, 0.2, age) * (1.0 - smoothstep(dur * 0.35, dur, age)) * (0.35 + 0.65 * fuel);
}

float smouldering(float age, float fuel) {
	float dur = burn_len(fuel);
	return smoothstep(0.0, 0.3, age) * exp(-max(age - dur, 0.0) * 0.45) * (0.3 + 0.7 * fuel);
}

vec3 fire_colour(float x) {
	x = clamp(x, 0.0, 1.0);
	vec3 c = vec3(smoothstep(0.0, 0.3, x), smoothstep(0.18, 0.7, x) * 0.82, smoothstep(0.55, 1.0, x) * 0.7);
	return c * (0.55 + 0.45 * x);
}

void fragment() {
	vec2 tsz = vec2(textureSize(effect_tex, 0));
	vec2 asp = vec2(tsz.x / max(tsz.y, 1.0), 1.0);
	float tf = clip_time - start_time;
	float sd = float(seed) * 0.731;
	vec2 q = UV * asp;

	float fuel = fuel_at(UV);
	float t_arr = arrival(UV);
	float jitter = sim_fbm(q * 26.0 + sd, 4) * (0.6 + 0.9 * fuel) * clamp(t_arr * 0.5, 0.0, 1.0);
	float age = tf - (t_arr + jitter);

	float heat_below = 0.0;
	for (int j = 1; j <= 4; j++) {
		vec2 p = UV + vec2(0.0, float(j) * 0.02);
		heat_below += burning(tf - arrival(p), fuel_at(p));
	}
	float hx = sim_noise(q * 30.0 + vec2(0.0, tf * 3.0)) - 0.5;
	float hy = sim_noise(q * 30.0 + vec2(5.2, tf * 3.0)) - 0.5;
	vec2 haze = vec2(hx, hy) * 0.006 * clamp(heat_below, 0.0, 1.0);
	vec4 src = texture(effect_tex, UV + haze);
	float alpha = src.a;
	vec3 pic = src.rgb / max(alpha, 0.0001);
	float l = sim_luma(pic);

	vec3 col = pic;
	float pre = clamp(1.0 + age / 0.5, 0.0, 1.0) * step(age, 0.0);
	col = mix(col, col * vec3(0.92, 0.72, 0.5), pre * pre * 0.55);

	float dur = burn_len(fuel);
	float burnt = smoothstep(dur * 0.15, dur * 0.9, age);
	float grain = sim_fbm(q * 90.0 + sd, 3);
	float crack = sim_fbm(q * 9.0 + 3.1 + sd, 5);
	vec3 coal = vec3(0.022, 0.019, 0.017) + l * vec3(0.07, 0.062, 0.055) * (0.7 + 0.6 * grain);
	float ash = smoothstep(0.52, 0.68, crack + fuel * 0.22 - 0.08) * smoothstep(dur, dur + 4.0, age);
	vec3 ash_col = vec3(0.52, 0.5, 0.48) * (0.6 + 0.4 * grain) * (0.55 + 0.45 * l);
	vec3 burnt_col = mix(coal, ash_col, ash * 0.8);
	col = mix(col, burnt_col, burnt * charring);

	float sm = smouldering(age, fuel);
	float rn = sim_fbm(q * 34.0 + sd * 2.0, 4);
	float ridge = 1.0 - abs(2.0 * rn - 1.0);
	float vein = smoothstep(0.9, 0.98, ridge) * smoothstep(0.35, 0.6, sim_noise(q * 6.0 + sd));
	float dots = smoothstep(0.9, 0.97, sim_noise(q * 220.0 + sd));
	float flick = 0.75 + 0.25 * sin(tf * 7.0 + rn * 30.0);
	float fresh = exp(-max(age - dur * 0.6, 0.0) * 1.8);
	float ember = (vein * fresh + dots * sm * 0.8) * flick * embers * smoothstep(0.0, 0.3, age);
	col = mix(col, vec3(1.0, 0.36, 0.06), clamp(ember, 0.0, 1.0) * 0.9);

	float flame_len = 0.025 + 0.13 * flames;
	float heat = 0.0;
	float wx = wind * 0.35;
	for (int j = 0; j < 10; j++) {
		float h = float(j) / 9.0;
		vec2 p = UV + vec2(-wx * h * flame_len, h * flame_len);
		float ta = arrival(p);
		float a = tf - ta - sim_fbm(p * asp * 26.0 + sd, 2) * 1.0 * clamp(ta * 0.5, 0.0, 1.0);
		heat += burning(a, fuel_at(p)) * (1.0 - h * 0.85);
	}
	heat /= 4.0;
	float tongues = sim_fbm(vec2(q.x * 16.0 - wx * tf * 2.0, q.y * 7.0 + tf * 3.4) + sd, 4);
	float tongues2 = sim_noise(vec2(q.x * 40.0, q.y * 16.0 + tf * 6.0) + sd);
	float b0 = burning(age, fuel);
	float flame = clamp(heat * (0.35 + 1.5 * tongues) * (0.75 + 0.5 * tongues2) + b0 * 0.65, 0.0, 1.6);
	flame *= step(0.001, flames);
	float fa = smoothstep(0.3, 0.85, flame);
	col = mix(col, fire_colour(flame * 0.62), fa * 0.9);
	col += fire_colour(flame) * smoothstep(0.9, 1.6, flame) * 0.35;

	float dens = 0.0;
	float lit = 0.0;
	for (int j = 1; j <= 12; j++) {
		float h = float(j) * 0.034;
		float sway = (sim_noise(vec2(float(j) * 0.7, tf * 0.4 + sd)) - 0.5) * 0.06 * float(j) / 12.0;
		vec2 p = UV + vec2(-wind * h * 0.9 + sway, h);
		float a = tf - arrival(p);
		float f = fuel_at(p);
		dens += (burning(a, f) * 1.2 + smouldering(a, f) * 0.5) * (1.0 - float(j) / 14.0);
		lit += burning(a, f) * step(float(j), 4.0);
	}
	float billow = sim_fbm(vec2(q.x * 5.0 + wind * tf * 0.25, q.y * 4.0 + tf * 0.5) + sd, 5);
	dens = clamp(dens * 0.3 * (0.25 + 1.5 * billow), 0.0, 1.0) * smoke;
	vec3 smoke_col = mix(vec3(0.12, 0.115, 0.11), vec3(0.33, 0.31, 0.29), billow) + vec3(0.55, 0.22, 0.04) * clamp(lit * 0.5, 0.0, 1.0);
	col = mix(col, smoke_col, dens * 0.6 * (1.0 - fa));

	float glow = 0.0;
	for (int k = 0; k < 12; k++) {
		float ang = float(k) * 0.5236 + 0.3;
		float rad = (k % 2 == 0) ? 0.05 : 0.12;
		vec2 p = UV + vec2(cos(ang) / asp.x, sin(ang)) * rad;
		glow += burning(tf - arrival(p), fuel_at(p)) * ((k % 2 == 0) ? 1.0 : 0.6);
	}
	glow = clamp(glow / 5.0, 0.0, 1.0) * (1.0 - burnt * 0.6);
	vec3 gl = vec3(1.0, 0.5, 0.16) * glow * 0.55;
	col = 1.0 - (1.0 - clamp(col, 0.0, 1.0)) * (1.0 - gl);

	col = clamp(col, 0.0, 1.0);
	COLOR = vec4(col * alpha, alpha);
}
