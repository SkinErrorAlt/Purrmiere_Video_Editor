shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/slime_mould/sim.gdshaderinc"

uniform float food : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	ivec2 sz = textureSize(TEXTURE, 0);
	ivec2 me = clamp(ivec2(UV * vec2(sz)), ivec2(0), sz - 1);
	vec4 here = texelFetch(TEXTURE, me, 0);
	float r = max(2.0, float(sz.y) / 30.0);
	float around = 0.0;
	for (int k = 0; k < 12; k++) {
		float a = float(k) * 0.5236;
		for (int s = 1; s <= 2; s++) {
			ivec2 n = clamp(me + ivec2(round(vec2(cos(a), sin(a)) * r * float(s))), ivec2(0), sz - 1);
			around += texelFetch(TEXTURE, n, 0).b;
		}
	}
	around /= 24.0;
	float l = here.a;
	float peak = l - around;
	float need = mix(0.6, 0.1, food);
	float f = smoothstep(need, need + 0.15, peak) * smoothstep(0.45, 0.75, l);
	COLOR = vec4(here.rg, here.b, f);
}
