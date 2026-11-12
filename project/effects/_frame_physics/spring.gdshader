shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/_frame_physics/fp.gdshaderinc"

uniform float bounce = 1.5;
uniform float settle = 1.0;
uniform float spread = 0.0;
uniform vec2 gain = vec2(1.0, 1.0);
uniform vec4 ratios = vec4(1.0, 0.8, 2.4, 0.6);
uniform vec4 settles = vec4(1.0, 1.0, 0.6, 1.4);

float h1(float n) {
	return fract(sin(n * 91.3458 + 7.13) * 47453.5453);
}

void fragment() {
	vec2 osz = fp_out_size(UV);
	ivec2 p = ivec2(floor(UV * osz));
	if (p.x >= 20 || p.y >= 2) {
		COLOR = vec4(0.0);
	} else {
		float k = float(p.x);
		float hm = p.x == 0 ? 1.0 : exp2((h1(k) * 2.0 - 1.0) * spread);
		float sm = p.x == 0 ? 1.0 : exp2((h1(k + 31.0) * 2.0 - 1.0) * spread * 0.6);
		if (p.x >= 16) {
			hm = ratios[p.x - 16];
			sm = settles[p.x - 16];
		}
		int pairs = fp_pairs(TEXTURE);
		vec4 r = fp_respond(TEXTURE, pairs, history_fps, fp_spring(bounce * hm, settle * sm), gain);
		COLOR = p.y == 0 ? fp_pack2(r.xy, FP_XRANGE) : fp_pack2(r.zw, FP_VRANGE);
	}
}
