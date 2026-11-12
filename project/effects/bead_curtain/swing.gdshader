shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_frame_physics/fp.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D atlas_tex : filter_nearest, repeat_disable;
uniform int strings = 96;
uniform float camera = 1.0;

void fragment() {
	vec2 osz = fp_out_size(UV);
	ivec2 p = ivec2(floor(UV * osz));
	vec2 sz = vec2(textureSize(effect_tex, 0));
	float asp = sz.x / sz.y;
	float n = float(max(strings, 4));
	float pitch_x = 1.0 / n;
	float pitch_y = pitch_x * asp * 1.1547;
	int rows = int(ceil(1.0 / pitch_y)) + 3;
	if (float(p.x) >= n || p.y >= rows) {
		COLOR = fp_pack2(vec2(0.0), 0.25);
	} else {
		ivec2 fs = fp_flow_size(textureSize(atlas_tex, 0));
		vec2 cam = fp_field_camera(TEXTURE, fs).xy * 0.6;
		float xs = (float(p.x) + 0.5) * pitch_x;
		float stagger = (p.x % 2 == 0) ? 0.0 : 0.5;
		float yc = (float(p.y - 1) + 0.5 + stagger) * pitch_y;
		float y = clamp(yc, 0.0, 1.0);
		vec2 u = fp_field(TEXTURE, vec2(xs, y), fs, 0, 0.25);
		float hang = 0.25 + 0.75 * y;
		float dx = (u.x + cam.x * camera) * hang;
		dx = 0.045 * tanh(dx / 0.045);
		float lift = dx * dx / max(y + 0.05, 0.05) * 0.5;
		COLOR = fp_pack2(vec2(dx, -lift), 0.25);
	}
}
