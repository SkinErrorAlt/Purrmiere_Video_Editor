shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/turing_bloom/sim.gdshaderinc"

uniform vec2 tex_size = vec2(2.0);
uniform int grows_from : hint_range(0, 2) = 0;
uniform float edge_level : hint_range(0.0, 1.0) = 0.35;
uniform int seed : hint_range(0, 9999) = 0;

float lum(sampler2D t, vec2 uv) {
	vec4 c = texture(t, uv);
	return sim_luma(c.rgb / max(c.a, 0.001));
}

void fragment() {
	vec2 px = 1.0 / tex_size;
	float l = lum(TEXTURE, UV);
	float jxx = 0.0;
	float jxy = 0.0;
	float jyy = 0.0;
	float edge = 0.0;
	float wide = 0.0;
	float spacing = tex_size.y / 90.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 c = UV + vec2(float(i), float(j)) * spacing * px;
			float gx = lum(TEXTURE, c + vec2(2.0, 0.0) * px) - lum(TEXTURE, c - vec2(2.0, 0.0) * px);
			float gy = lum(TEXTURE, c + vec2(0.0, 2.0) * px) - lum(TEXTURE, c - vec2(0.0, 2.0) * px);
			float w = exp(-0.25 * float(i * i + j * j));
			jxx += gx * gx * w;
			jxy += gx * gy * w;
			jyy += gy * gy * w;
			wide += lum(TEXTURE, c);
			if (i == 0 && j == 0) {
				edge = length(vec2(gx, gy));
			}
		}
	}
	wide /= 25.0;
	float theta = 0.5 * atan(2.0 * jxy, jxx - jyy + 1e-9) + 1.5707963;
	float ang = fract(theta / 3.14159265);
	bool src = false;
	float need = mix(0.45, 0.04, edge_level);
	if (grows_from == 0) {
		src = edge > need;
	} else if (grows_from == 1) {
		src = l < mix(0.05, 0.45, edge_level);
	} else {
		src = true;
	}
	float n = sim_hash(floor(UV * tex_size * 0.5) + float(seed) * 13.1);
	float p = 0.5 + (l - wide) * 1.2 + (n - 0.5) * 0.2;
	COLOR = vec4(sim_pack(src ? 0.0 : 1.0), clamp(p, 0.0, 1.0), ang);
}
