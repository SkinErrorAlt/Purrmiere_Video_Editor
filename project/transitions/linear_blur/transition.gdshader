shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float intensity : hint_range(0.0, 0.4) = 0.1;
uniform int shape = 0;
uniform int timing = 0;

const int GRID = 5;
const int LINE = 16;

float dither(vec2 uv) {
	vec2 px = floor(uv * frame_px);
	return fract(52.9829189 * fract(dot(px, vec2(0.06711056, 0.00583715))));
}

vec4 both_at(vec2 suv, float mixer) {
	return mix(from_clamped(suv), to_clamped(suv), mixer);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float mixer = tr_ease(p, timing == 1 ? 3 : 0);
	float d = intensity * (0.5 - abs(0.5 - p));
	if (d < 0.000001) {
		return mix(texture(from_tex, uv), texture(to_tex, uv), mixer);
	}
	vec2 reach = vec2(d / tr_ratio(), d);
	float j = dither(uv);
	vec2 jj = vec2(j, fract(j * 7.31 + 0.37));
	vec4 acc = vec4(0.0);
	float n = 0.0;
	if (shape == 0) {
		for (int y = 0; y < GRID; y++) {
			for (int x = 0; x < GRID; x++) {
				float cell = float(y * GRID + x);
				vec2 cj = fract(jj + vec2(cell * 0.6180339, cell * 0.7548777));
				vec2 f = (vec2(float(x), float(y)) + cj) / float(GRID) - 0.5;
				acc += both_at(uv + f * 2.0 * reach, mixer);
				n += 1.0;
			}
		}
	} else {
		vec2 dir = shape == 1 ? vec2(reach.x, 0.0) : vec2(0.0, reach.y);
		for (int i = 0; i < LINE; i++) {
			float f = (float(i) + j) / float(LINE) - 0.5;
			acc += both_at(uv + dir * 2.0 * f, mixer);
			n += 1.0;
		}
	}
	return acc / n;
}

void fragment() {
	COLOR = transition(UV);
}
