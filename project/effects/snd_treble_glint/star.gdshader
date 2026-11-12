shader_type canvas_item;
render_mode blend_disabled;

#include "res://engine/sound.gdshaderinc"

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float length_px : hint_range(4.0, 300.0) = 110.0;
uniform int points = 1;
uniform float rotation : hint_range(-180.0, 180.0) = 15.0;

void fragment() {
	int arms = points == 0 ? 2 : (points == 1 ? 3 : 4);
	float len = length_px * px_scale;
	vec3 acc = vec3(0.0);
	for (int a = 0; a < 4; a++) {
		if (a >= arms) {
			break;
		}
		float ang = radians(rotation) + float(a) * 3.14159265 / float(arms);
		vec2 dir = vec2(cos(ang), sin(ang)) / max(tex_size, vec2(1.0));
		for (int i = 1; i <= 32; i++) {
			float t = float(i) / 32.0;
			float d = t * len * 0.5;
			float w = pow(1.0 - t, 1.8);
			acc += (texture(TEXTURE, UV + dir * d).rgb + texture(TEXTURE, UV - dir * d).rgb) * w;
		}
	}
	vec3 core = texture(TEXTURE, UV).rgb;
	COLOR = vec4(acc * 0.1 + core * 0.9, 1.0);
}
