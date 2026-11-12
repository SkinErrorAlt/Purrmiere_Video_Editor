shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_motion_kit/kit.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform int kind = 0;
uniform float glow = 0.5;
uniform vec4 ember_colour : source_color = vec4(1.0, 0.55, 0.16, 1.0);

void fragment() {
	vec2 psz = vec2(textureSize(TEXTURE, 0));
	vec4 s = texture(TEXTURE, UV);
	vec3 halo = vec3(0.0);
	float ha = 0.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			float w = exp(-float(i * i + j * j) / 3.0);
			vec4 q = texture(TEXTURE, UV + vec2(float(i), float(j)) * 1.5 / psz);
			halo += q.rgb * q.a * w;
			ha += q.a * w;
		}
	}
	halo /= 8.0;
	ha /= 8.0;
	vec4 src = texture(effect_tex, UV);
	float a = src.a;
	vec3 pic = a > 0.0001 ? src.rgb / a : vec3(0.0);
	vec3 add;
	vec3 outc;
	if (kind == 0) {
		vec3 lab = kit_srgb_to_oklab(s.rgb);
		lab.yz *= 1.2;
		vec3 c = kit_oklab_to_srgb(lab);
		outc = mix(pic, c, s.a);
		add = halo * glow * 0.25;
	} else if (kind == 1) {
		float heat = clamp(kit_luma(s.rgb) * 0.6 + 0.5, 0.0, 1.0);
		vec3 ember = mix(ember_colour.rgb * vec3(1.0, 0.7, 0.6), mix(ember_colour.rgb, vec3(1.0, 0.95, 0.8), 0.5), heat);
		outc = pic;
		add = ember * s.a * 1.3 + ember_colour.rgb * ha * glow * 0.6;
	} else {
		vec3 lab = kit_srgb_to_oklab(s.rgb);
		lab.x = max(lab.x, 0.75);
		lab.yz *= 1.4;
		vec3 c = kit_oklab_to_srgb(lab);
		outc = pic;
		add = c * s.a * 1.1 + halo * glow * 0.8;
	}
	outc = 1.0 - (1.0 - outc) * (1.0 - clamp(add, 0.0, 1.0));
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
