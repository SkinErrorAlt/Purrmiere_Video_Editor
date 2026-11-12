shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/rising_flood/sim.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D grid_tex : filter_nearest, repeat_disable;
uniform float clip_time = 0.0;
uniform float level : hint_range(0.0, 1.0) = 0.55;
uniform float rise_time : hint_range(0.0, 60.0) = 6.0;
uniform int low_ground : hint_range(0, 1) = 0;
uniform float lie : hint_range(0.0, 1.0) = 0.25;
uniform vec4 water : source_color = vec4(0.2, 0.24, 0.2, 1.0);
uniform float murk : hint_range(0.0, 1.0) = 0.5;
uniform float ripples : hint_range(0.0, 1.0) = 0.5;
uniform float wind : hint_range(-1.0, 1.0) = 0.3;
uniform int seed : hint_range(0, 9999) = 0;

float wave(vec2 p, float t, float sd) {
	float h = 0.0;
	vec2 w = p + vec2(sim_fbm(p * 2.0 + sd, 2), sim_fbm(p * 2.0 + sd + 4.0, 2)) * 0.07;
	h += sin(dot(w, vec2(0.95, 0.3)) * 40.0 - t * (2.4 + wind)) * 0.3;
	h += sin(dot(w, vec2(-0.6, 0.8)) * 55.0 - t * 3.0 + sd * 1.7) * 0.2;
	h += sin(dot(w, vec2(0.3, 0.95)) * 75.0 - t * 3.6) * 0.12;
	h += (sim_fbm(w * 20.0 + vec2(t * 0.25 * (1.0 + wind), t * 0.1) + sd, 3) - 0.5) * 0.6;
	return h;
}

float ground_at(vec2 uv) {
	vec3 c = texture(effect_tex, uv).rgb;
	float l = sim_luma(c);
	l = low_ground == 1 ? 1.0 - l : l;
	return mix(1.0 - uv.y, l, lie);
}

float surface_at(vec2 uv, float lv) {
	float spill = sim_field(grid_tex, uv);
	return mix(spill - 0.3, lv, smoothstep(0.0, 0.08, lv - spill)) * step(spill, lv) - (1.0 - step(spill, lv));
}

float ground_soft(vec2 uv) {
	return mix(sim_field_ba(grid_tex, uv), ground_at(uv) * 0.94 + 0.03, 0.7);
}

void fragment() {
	vec2 tsz = vec2(textureSize(effect_tex, 0));
	vec2 asp = vec2(tsz.x / max(tsz.y, 1.0), 1.0);
	vec2 q = UV * asp;
	float sd = float(seed) * 0.913;
	float t = clip_time;

	float lv = level;
	if (rise_time > 0.0) {
		lv *= clamp(clip_time / rise_time, 0.0, 1.0);
	}
	lv = lv * 1.02 - 0.01;
	float spill = sim_field(grid_tex, UV);
	vec2 px = 1.0 / tsz;
	float g = 0.0;
	g += ground_at(UV + px * vec2(-1.5, -1.5));
	g += ground_at(UV + px * vec2(1.5, -1.5));
	g += ground_at(UV + px * vec2(-1.5, 1.5));
	g += ground_at(UV + px * vec2(1.5, 1.5));
	g = g * 0.25 * 0.94 + 0.03;
	float coarse = sim_field_ba(grid_tex, UV);
	float ground = mix(coarse, g, 0.7);

	float over = lv - spill;
	float fill = smoothstep(0.0, 0.08, over);
	float surface = mix(spill - 0.3, lv, fill);
	float depth = surface - ground;
	float wet = step(0.0, over) * smoothstep(-0.002, 0.004, depth);

	float e = 0.0015;
	float w0 = wave(q, t, sd);
	float wx = wave(q + vec2(e, 0.0), t, sd);
	float wy = wave(q + vec2(0.0, e), t, sd);
	vec2 slope = vec2(wx - w0, wy - w0) / e * 0.0006 * ripples;
	float dk = clamp(depth * 4.0, 0.0, 1.0);
	vec2 bent = UV + slope * (0.3 + 2.0 * dk) * 0.02 * wet;
	vec4 src = texture(effect_tex, UV);
	float alpha = src.a;
	vec3 pic = src.rgb / max(alpha, 0.0001);
	vec4 under4 = texture(effect_tex, bent);
	vec3 under = under4.rgb / max(under4.a, 0.0001);

	vec3 col = pic;
	float damp = step(0.0, over + 0.02) * (1.0 - smoothstep(0.0, 0.03, -depth)) * (1.0 - wet);
	col *= 1.0 - 0.3 * damp;

	float dd = max(depth, 0.0) * (2.0 + 10.0 * murk);
	vec3 absorb = exp(-dd * vec3(2.4, 1.0, 0.75));
	vec3 tint = water.rgb;
	vec3 seen = under * absorb + tint * (1.0 - absorb) * (0.6 + 0.4 * murk);
	float cn = abs(sin(sim_fbm(q * 18.0 + vec2(t * 0.4, -t * 0.3) + sd, 3) * 12.0));
	float caustic = pow(1.0 - cn, 10.0) * (1.0 - dk) * 0.2 * ripples;
	seen += vec3(0.9, 1.0, 0.95) * caustic * absorb.g;
	vec3 nrm = normalize(vec3(-slope * 60.0, 1.0));
	float fres = 0.12 + 0.6 * clamp((1.0 - nrm.z) * 8.0, 0.0, 1.0);
	vec3 sky = mix(tint * 1.6 + 0.25, vec3(0.75, 0.82, 0.88), 0.5);
	seen = mix(seen, sky, clamp(fres * (0.35 + 0.4 * dk), 0.0, 0.45));
	float glint = pow(max(dot(nrm, normalize(vec3(0.25, -0.35, 0.9))), 0.0), 400.0);
	float shore = (1.0 - smoothstep(0.0, 0.012, depth)) * wet;
	float foam = shore * smoothstep(0.45, 0.75, sim_fbm(q * 90.0 + vec2(t * 0.6, 0.0) + sd, 3) + 0.25 * sin(t * 2.0 + q.x * 40.0));

	float yw = -1.0;
	float stp = 0.012;
	for (int k = 1; k <= 28; k++) {
		vec2 p = vec2(UV.x, UV.y - float(k) * stp);
		if (p.y < 0.0) {
			break;
		}
		if (surface_at(p, lv) - ground_soft(p) < 0.0) {
			float lo = p.y;
			float hi = p.y + stp;
			for (int r = 0; r < 5; r++) {
				float mid = 0.5 * (lo + hi);
				vec2 mp = vec2(UV.x, mid);
				if (surface_at(mp, lv) - ground_soft(mp) < 0.0) {
					lo = mid;
				} else {
					hi = mid;
				}
			}
			yw = 0.5 * (lo + hi);
			break;
		}
	}
	vec3 refl = sky;
	if (yw >= 0.0) {
		vec2 ruv = vec2(UV.x, clamp(2.0 * yw - UV.y, 0.0, 1.0)) + slope * vec2(1.0, 3.0) * 0.06;
		vec4 r4 = texture(effect_tex, ruv);
		refl = r4.rgb / max(r4.a, 0.0001);
		refl = mix(refl, sky, smoothstep(0.0, 0.35, UV.y - yw) * 0.6);
	}
	float rmix = mix(0.25, 0.6, 1.0 - murk * 0.6) * (0.6 + 0.4 * dk);
	seen = mix(seen, refl * 0.85 + tint * 0.1, rmix);
	seen += vec3(1.0, 0.98, 0.92) * glint * 1.2 * ripples;
	seen = mix(seen, vec3(0.92, 0.95, 0.95), foam * 0.6);
	col = mix(col, seen, wet);
	col = clamp(col, 0.0, 1.0);
	COLOR = vec4(col * alpha, alpha);
}
