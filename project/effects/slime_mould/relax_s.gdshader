shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/slime_mould/sim.gdshaderinc"

uniform float hop = 1.0;
uniform float speed : hint_range(0.02, 1.0) = 0.15;
uniform int seed : hint_range(0, 9999) = 0;

const float T_RANGE = 120.0;

float cost_at(ivec2 c, float l, ivec2 sz) {
	vec2 uv = (vec2(c) + 0.5) / vec2(sz);
	float n = sim_fbm(uv * vec2(float(sz.x) / float(sz.y), 1.0) * 3.5 + float(seed) * 0.37, 4);
	return 1.25 - 0.75 * sqrt(clamp(l, 0.0, 1.0)) + 1.6 * (n - 0.5) * (n - 0.5) * 4.0;
}

void fragment() {
	ivec2 sz = textureSize(TEXTURE, 0);
	ivec2 me = clamp(ivec2(UV * vec2(sz)), ivec2(0), sz - 1);
	vec4 here = texelFetch(TEXTURE, me, 0);
	float best = sim_unpack(here.rg) * T_RANGE;
	float c0 = cost_at(me, here.b, sz);
	float r = max(1.0, floor(hop * float(sz.y) / 68.0 + 0.5));
	for (int k = 0; k < 16; k++) {
		float a = float(k) * 0.39269908;
		ivec2 o = ivec2(round(vec2(cos(a), sin(a)) * r));
		ivec2 n = me + o;
		if (o == ivec2(0) || n.x < 0 || n.y < 0 || n.x >= sz.x || n.y >= sz.y) {
			continue;
		}
		vec4 there = texelFetch(TEXTURE, n, 0);
		float tn = sim_unpack(there.rg) * T_RANGE;
		if (tn >= best) {
			continue;
		}
		ivec2 m = me + o / 2;
		float cost = (c0 + 2.0 * cost_at(m, texelFetch(TEXTURE, m, 0).b, sz) + cost_at(n, there.b, sz)) * 0.25;
		best = min(best, tn + length(vec2(o)) / float(sz.y) * max(cost, 0.35) / speed);
	}
	COLOR = vec4(sim_pack(best / T_RANGE), here.b, here.a);
}
