shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/rising_flood/sim.gdshaderinc"

uniform float hop = 1.0;

void fragment() {
	ivec2 sz = textureSize(TEXTURE, 0);
	ivec2 me = clamp(ivec2(UV * vec2(sz)), ivec2(0), sz - 1);
	vec4 here = texelFetch(TEXTURE, me, 0);
	float best = sim_unpack(here.rg);
	float h0 = sim_unpack(here.ba);
	float r = max(1.0, floor(hop * float(sz.y) / 68.0 + 0.5));
	for (int k = 0; k < 16; k++) {
		float a = float(k) * 0.39269908;
		ivec2 o = ivec2(round(vec2(cos(a), sin(a)) * r));
		ivec2 n = me + o;
		if (o == ivec2(0) || n.x < 0 || n.y < 0 || n.x >= sz.x || n.y >= sz.y) {
			continue;
		}
		float sn = sim_unpack(texelFetch(TEXTURE, n, 0).rg);
		if (sn >= best) {
			continue;
		}
		float ridge = max(h0, sn);
		int steps = int(min(max(abs(float(o.x)), abs(float(o.y))), 16.0));
		for (int s = 1; s < 16; s++) {
			if (s >= steps) {
				break;
			}
			ivec2 m = me + ivec2(round(vec2(o) * float(s) / float(steps)));
			ridge = max(ridge, sim_unpack(texelFetch(TEXTURE, m, 0).ba));
			if (ridge >= best) {
				break;
			}
		}
		best = min(best, ridge);
	}
	COLOR = vec4(sim_pack(best), here.ba);
}
