shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/lava_flow/sim.gdshaderinc"

uniform vec2 tex_size = vec2(2.0);
uniform vec2 vent = vec2(0.5, 0.08);
uniform float lie : hint_range(0.0, 1.0) = 0.25;
uniform int low_ground : hint_range(0, 1) = 0;
uniform int seed : hint_range(0, 9999) = 0;

void fragment() {
	vec2 px = 1.0 / tex_size;
	float acc = 0.0;
	float al = 0.0;
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 4; i++) {
			vec4 c = texture(TEXTURE, UV + (vec2(float(i), float(j)) - 1.5) * 2.0 * px);
			acc += sim_luma(c.rgb / max(c.a, 0.001));
			al += c.a;
		}
	}
	float l = acc / 16.0;
	if (low_ground == 1) {
		l = 1.0 - l;
	}
	vec2 aspect = vec2(tex_size.x / tex_size.y, 1.0);
	float bumps = sim_fbm(UV * aspect * 5.0 + float(seed) * 0.91, 3) - 0.5;
	float h = mix(1.0 - UV.y, l, lie) + bumps * 0.08;
	float r = max(0.014, 0.75 * 8.0 / tex_size.y);
	float t = length((UV - vent) * aspect) < r ? 0.0 : 1.0;
	COLOR = vec4(sim_pack(t), sim_pack(clamp(h, 0.0, 1.0)));
}
