shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/rising_flood/sim.gdshaderinc"

uniform vec2 tex_size = vec2(2.0);
uniform int low_ground : hint_range(0, 1) = 0;
uniform int source : hint_range(0, 2) = 0;
uniform float lie : hint_range(0.0, 1.0) = 0.25;

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
	float h = acc / 16.0;
	if (low_ground == 1) {
		h = 1.0 - h;
	}
	h = mix(1.0 - UV.y, h, lie);
	h = clamp(h * 0.94 + 0.03, 0.0, 1.0);
	ivec2 sz = ivec2(round(tex_size * 0.125));
	float gy = UV.y;
	float gx = UV.x;
	float edge_px = 1.5 / max(float(sz.y), 2.0);
	bool inlet = false;
	if (source == 0) {
		inlet = gy > 1.0 - edge_px;
	} else if (source == 1) {
		inlet = gy > 1.0 - edge_px || gy < edge_px || gx < edge_px * float(sz.y) / float(max(sz.x, 1)) || gx > 1.0 - edge_px * float(sz.y) / float(max(sz.x, 1));
	} else {
		inlet = true;
	}
	COLOR = vec4(sim_pack(inlet ? h : 1.0), sim_pack(h));
}
