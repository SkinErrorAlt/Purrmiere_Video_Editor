shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/wildfire/sim.gdshaderinc"

uniform float hop = 1.0;
uniform float speed : hint_range(0.02, 1.0) = 0.25;
uniform float climb : hint_range(0.0, 1.0) = 0.5;
uniform float wind : hint_range(-1.0, 1.0) = 0.2;

const float T_RANGE = 120.0;

float cost_of(float f) {
	if (f < 0.04) {
		return 40.0;
	}
	return 1.0 / (0.12 + 0.88 * f * f);
}

void fragment() {
	ivec2 sz = textureSize(TEXTURE, 0);
	ivec2 me = clamp(ivec2(UV * vec2(sz)), ivec2(0), sz - 1);
	vec4 here = texelFetch(TEXTURE, me, 0);
	float t = sim_unpack(here.rg) * T_RANGE;
	float f0 = here.b;
	float c0 = cost_of(f0);
	float r = max(1.0, floor(hop * float(sz.y) / 68.0 + 0.5));
	float best = t;
	for (int k = 0; k < 16; k++) {
		float a = float(k) * 0.39269908;
		vec2 d = vec2(cos(a), sin(a));
		ivec2 o = ivec2(round(d * r));
		if (o == ivec2(0)) {
			continue;
		}
		ivec2 n = me + o;
		if (n.x < 0 || n.y < 0 || n.x >= sz.x || n.y >= sz.y) {
			continue;
		}
		vec4 there = texelFetch(TEXTURE, n, 0);
		float tn = sim_unpack(there.rg) * T_RANGE;
		if (tn >= best) {
			continue;
		}
		ivec2 m = me + o / 2;
		float fm = texelFetch(TEXTURE, m, 0).b;
		float cost = (c0 + 2.0 * cost_of(fm) + cost_of(there.b)) * 0.25;
		vec2 travel = normalize(-vec2(o));
		float push = 1.0 + climb * 1.6 * max(dot(travel, vec2(0.0, -1.0)), -0.5) + wind * 1.4 * travel.x;
		push = max(push, 0.25);
		float dist = length(vec2(o)) / float(sz.y);
		best = min(best, tn + dist * cost / (speed * push));
	}
	COLOR = vec4(sim_pack(best / T_RANGE), f0, 1.0);
}
