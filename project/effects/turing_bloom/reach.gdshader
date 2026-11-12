shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/turing_bloom/sim.gdshaderinc"

uniform float hop = 1.0;
uniform int seed : hint_range(0, 9999) = 0;

void fragment() {
	ivec2 sz = textureSize(TEXTURE, 0);
	ivec2 me = clamp(ivec2(UV * vec2(sz)), ivec2(0), sz - 1);
	vec4 here = texelFetch(TEXTURE, me, 0);
	float best = sim_unpack(here.rg);
	float r = max(1.0, floor(hop * float(sz.y) / 68.0 + 0.5));
	vec2 asp = vec2(float(sz.x) / float(sz.y), 1.0);
	float rough = 0.7 + 0.6 * sim_fbm(UV * asp * 6.0 + float(seed) * 0.71, 3);
	for (int k = 0; k < 16; k++) {
		float a = float(k) * 0.39269908;
		ivec2 o = ivec2(round(vec2(cos(a), sin(a)) * r));
		ivec2 n = me + o;
		if (o == ivec2(0) || n.x < 0 || n.y < 0 || n.x >= sz.x || n.y >= sz.y) {
			continue;
		}
		float dn = sim_unpack(texelFetch(TEXTURE, n, 0).rg);
		best = min(best, dn + length(vec2(o)) / float(sz.y) * 0.5 * rough);
	}
	COLOR = vec4(sim_pack(best), here.ba);
}
