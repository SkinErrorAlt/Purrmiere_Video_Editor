shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_frame_physics/fp.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float strength = 1.0;
uniform float roll = 6.0;
uniform int fill = 0;

void fragment() {
	vec2 lag = fp_x(TEXTURE, 16) * strength;
	float swing = fp_x(TEXTURE, 17).x * strength;
	vec2 osz = vec2(textureSize(effect_tex, 0));
	float asp = osz.x / osz.y;
	float th = radians(clamp(-roll * swing / 0.1, -25.0, 25.0));
	mat2 rot = mat2(vec2(cos(th), sin(th)), vec2(-sin(th), cos(th)));
	vec2 off = lag * vec2(asp, 1.0);
	float z = 1.0;
	if (fill == 0) {
		vec2 half_ = vec2(asp, 1.0) * 0.5;
		for (int i = 0; i < 2; i++) {
			vec2 r = abs(rot * (half_ * vec2(i == 0 ? -1.0 : 1.0, 1.0)));
			vec2 room = max(half_ - abs(off), vec2(0.05));
			z = max(z, max(r.x / room.x, r.y / room.y));
		}
	}
	vec2 p = (UV - 0.5) * vec2(asp, 1.0);
	vec2 s = rot * p / z + off;
	vec2 uv = s / vec2(asp, 1.0) + 0.5;
	if (lag == vec2(0.0) && swing == 0.0) {
		uv = UV;
	}
	COLOR = texture(effect_tex, fill == 0 ? clamp(uv, vec2(0.0), vec2(1.0)) : fp_mirror(uv));
}
