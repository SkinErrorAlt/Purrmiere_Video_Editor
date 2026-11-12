shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/wildfire/sim.gdshaderinc"

uniform vec2 tex_size = vec2(2.0);
uniform vec2 start = vec2(0.5, 0.85);
uniform int fires : hint_range(0, 6) = 1;
uniform int fuel_from : hint_range(0, 2) = 0;
uniform float dryness : hint_range(0.0, 1.0) = 0.6;
uniform int seed : hint_range(0, 9999) = 0;

const float T_RANGE = 120.0;

void fragment() {
	vec2 px = 1.0 / tex_size;
	vec3 acc = vec3(0.0);
	float alpha = 0.0;
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 4; i++) {
			vec2 o = (vec2(float(i), float(j)) - 1.5) * 2.0;
			vec4 c = texture(TEXTURE, UV + o * px * 1.0);
			acc += c.rgb;
			alpha += c.a;
		}
	}
	alpha /= 16.0;
	vec3 col = acc / 16.0 / max(alpha, 0.001);
	float l = sim_luma(col);
	float sat = max(max(col.r, col.g), col.b) - min(min(col.r, col.g), col.b);
	float green = clamp((col.g - max(col.r, col.b)) * 3.0, 0.0, 1.0);
	float f = l;
	if (fuel_from == 1) {
		f = 1.0 - l;
	} else if (fuel_from == 2) {
		f = 0.75;
	}
	f *= 1.0 - 0.45 * green * sat;
	vec2 aspect = vec2(tex_size.x / tex_size.y, 1.0);
	float patch = sim_fbm(UV * aspect * 9.0 + float(seed) * 1.37, 3);
	f = f * (0.7 + 0.6 * patch);
	float lo = mix(0.55, 0.0, dryness);
	f = smoothstep(lo, lo + 0.45, f);
	f *= step(0.05, alpha);
	float t = 1.0;
	float r = max(0.012, 0.75 * 8.0 / tex_size.y);
	vec2 q = UV * aspect;
	if (length(q - start * aspect) < r) {
		t = 0.0;
	}
	for (int k = 0; k < 6; k++) {
		if (k >= fires) {
			break;
		}
		vec2 h = sim_hash2(vec2(float(k) * 7.31 + 1.0, float(seed) * 0.173 + 3.7));
		vec2 p = vec2(0.08, 0.08) + h * 0.84;
		float delay = sim_hash(h * 91.7) * 2.5 + float(k) * 0.6;
		if (length(q - p * aspect) < r) {
			t = min(t, delay / T_RANGE);
		}
	}
	COLOR = vec4(sim_pack(t), f, 1.0);
}
