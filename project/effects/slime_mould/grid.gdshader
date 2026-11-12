shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/slime_mould/sim.gdshaderinc"

uniform vec2 tex_size = vec2(2.0);
uniform vec2 start = vec2(0.5, 0.5);

void fragment() {
	vec2 px = 1.0 / tex_size;
	vec3 acc = vec3(0.0);
	float al = 0.0;
	float peak = 0.0;
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 4; i++) {
			vec4 c = texture(TEXTURE, UV + (vec2(float(i), float(j)) - 1.5) * 2.0 * px);
			acc += c.rgb;
			al += c.a;
			peak = max(peak, sim_luma(c.rgb));
		}
	}
	al /= 16.0;
	float l = sim_luma(acc / 16.0 / max(al, 0.001));
	vec2 aspect = vec2(tex_size.x / tex_size.y, 1.0);
	float t = length((UV - start) * aspect) < max(0.015, 0.75 * 8.0 / tex_size.y) ? 0.0 : 1.0;
	COLOR = vec4(sim_pack(t), l * step(0.05, al), peak * step(0.05, al));
}
