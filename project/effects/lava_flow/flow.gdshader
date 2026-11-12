shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/lava_flow/sim.gdshaderinc"

uniform float hop = 1.0;
uniform float speed : hint_range(0.02, 1.0) = 0.12;
uniform float runny : hint_range(0.0, 1.0) = 0.4;

const float T_RANGE = 120.0;

void fragment() {
	ivec2 sz = textureSize(TEXTURE, 0);
	ivec2 me = clamp(ivec2(UV * vec2(sz)), ivec2(0), sz - 1);
	vec4 here = texelFetch(TEXTURE, me, 0);
	float best = sim_unpack(here.rg) * T_RANGE;
	float h0 = sim_unpack(here.ba);
	float r = max(1.0, floor(hop * float(sz.y) / 68.0 + 0.5));
	float gxh = sim_unpack(texelFetch(TEXTURE, clamp(me + ivec2(1, 0), ivec2(0), sz - 1), 0).ba) - sim_unpack(texelFetch(TEXTURE, clamp(me - ivec2(1, 0), ivec2(0), sz - 1), 0).ba);
	float gyh = sim_unpack(texelFetch(TEXTURE, clamp(me + ivec2(0, 1), ivec2(0), sz - 1), 0).ba) - sim_unpack(texelFetch(TEXTURE, clamp(me - ivec2(0, 1), ivec2(0), sz - 1), 0).ba);
	vec2 fall = -vec2(gxh, gyh) * 0.5 * float(sz.y);
	float steep = length(fall);
	vec2 fall_dir = steep > 1e-4 ? fall / steep : vec2(0.0, 1.0);
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
		float dist = length(vec2(o)) / float(sz.y);
		ivec2 m = me + o / 2;
		float hm = sim_unpack(texelFetch(TEXTURE, m, 0).ba);
		float hn = sim_unpack(there.ba);
		float up = max(hm - hn, 0.0) + max(h0 - hm, 0.0);
		float down = max(hn - hm, 0.0) + max(hm - h0, 0.0);
		float slope_up = up / dist;
		float slope_down = down / dist;
		float cost = (4.0 - 1.5 * runny) * (1.0 + slope_up * mix(14.0, 5.0, runny));
		vec2 travel = normalize(-vec2(o));
		float along = max(dot(travel, fall_dir), 0.0);
		float mult = 1.0 + clamp(steep, 0.0, 2.0) * mix(5.0, 10.0, runny) * pow(along, 6.0);
		best = min(best, tn + dist * cost / (speed * mult));
	}
	COLOR = vec4(sim_pack(best / T_RANGE), here.ba);
}
