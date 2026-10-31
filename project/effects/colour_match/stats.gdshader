shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_nearest, repeat_disable;
uniform sampler2D reference : filter_linear, repeat_disable, hint_default_transparent;
uniform sampler2D mean_tex : filter_nearest, repeat_disable;
uniform bool from_ref = false;
uniform bool second = false;

const float GRID_X = 8.0;
const float GRID_Y = 4.0;
const int STEPS = 12;

vec3 to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float cube_root(float x) {
	return sign(x) * pow(abs(x), 1.0 / 3.0);
}

vec3 to_oklab(vec3 rgb) {
	vec3 c = to_linear(rgb);
	float l = cube_root(0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b);
	float m = cube_root(0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b);
	float s = cube_root(0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b);
	return vec3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s, 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s, 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s);
}

vec3 decode_mean(vec4 t) {
	return vec3(t.r, (t.g - 0.5) * 0.5, (t.b - 0.5) * 0.5);
}

vec4 fetch(vec2 uv) {
	if (from_ref) {
		return textureLod(reference, uv, 0.0);
	}
	return textureLod(effect_tex, uv, 0.0);
}

vec3 global_mean() {
	vec3 sum = vec3(0.0);
	float wsum = 0.0;
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 8; i++) {
			vec4 t = textureLod(mean_tex, (vec2(float(i), float(j)) + 0.5) / vec2(GRID_X, GRID_Y), 0.0);
			sum += decode_mean(t) * t.a;
			wsum += t.a;
		}
	}
	return wsum > 0.0001 ? sum / wsum : vec3(0.5, 0.0, 0.0);
}

void fragment() {
	vec2 grid = vec2(GRID_X, GRID_Y);
	vec2 cell = min(floor(UV * grid), grid - 1.0);
	vec3 mu = second ? global_mean() : vec3(0.0);
	vec3 acc = vec3(0.0);
	float wsum = 0.0;
	for (int j = 0; j < STEPS; j++) {
		for (int i = 0; i < STEPS; i++) {
			vec2 uv = (cell + (vec2(float(i), float(j)) + 0.5) / float(STEPS)) / grid;
			vec4 s = fetch(uv);
			float w = clamp(s.a, 0.0, 1.0);
			if (w < 0.01) {
				continue;
			}
			vec3 lab = to_oklab(s.rgb / s.a);
			if (second) {
				vec3 d = lab - mu;
				acc += d * d * w;
			} else {
				acc += lab * w;
			}
			wsum += w;
		}
	}
	float cover = wsum / float(STEPS * STEPS);
	vec3 v = wsum > 0.0001 ? acc / wsum : vec3(0.0);
	if (second) {
		vec3 sd = sqrt(max(v, vec3(0.0)));
		COLOR = vec4(clamp(vec3(sd.x * 2.0, sd.y * 4.0, sd.z * 4.0), 0.0, 1.0), cover);
	} else {
		COLOR = vec4(clamp(vec3(v.x, v.y * 2.0 + 0.5, v.z * 2.0 + 0.5), 0.0, 1.0), cover);
	}
}
