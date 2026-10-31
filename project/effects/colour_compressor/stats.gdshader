shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_nearest, repeat_disable;
uniform int target : hint_range(0, 1) = 0;
uniform vec4 centre : source_color = vec4(0.35, 0.6, 0.25, 1.0);
uniform float width : hint_range(5.0, 180.0) = 50.0;
uniform float softness : hint_range(0.0, 1.0) = 0.5;

const float GRID_X = 8.0;
const float GRID_Y = 4.0;
const int STEPS = 12;
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
const float SKIN_ANGLE = 2.1467;

vec2 chroma_of(vec3 rgb) {
	float y = dot(rgb, LUMA);
	return vec2((rgb.b - y) / 1.8556, (rgb.r - y) / 1.5748);
}

float centre_angle() {
	if (target == 0) {
		return SKIN_ANGLE;
	}
	vec2 cc = chroma_of(centre.rgb);
	return atan(cc.y, cc.x);
}

float wrap_angle(float x) {
	return x - 6.2831853 * floor((x + 3.1415927) / 6.2831853);
}

float in_range(vec2 cbcr, float ca) {
	float m = length(cbcr);
	float d = abs(wrap_angle(atan(cbcr.y, cbcr.x) - ca));
	float half_w = radians(width) * 0.5;
	float inner = half_w * (1.0 - softness);
	return (1.0 - smoothstep(inner, half_w + 0.0001, d)) * smoothstep(0.015, 0.045, m);
}

void fragment() {
	vec2 grid = vec2(GRID_X, GRID_Y);
	vec2 cell = min(floor(UV * grid), grid - 1.0);
	float ca = centre_angle();
	float msum = 0.0;
	float wsum = 0.0;
	for (int j = 0; j < STEPS; j++) {
		for (int i = 0; i < STEPS; i++) {
			vec2 uv = (cell + (vec2(float(i), float(j)) + 0.5) / float(STEPS)) / grid;
			vec4 s = textureLod(effect_tex, uv, 0.0);
			if (s.a < 0.01) {
				continue;
			}
			vec2 cbcr = chroma_of(clamp(s.rgb / s.a, 0.0, 1.0));
			float w = in_range(cbcr, ca) * s.a;
			msum += length(cbcr) * w;
			wsum += w;
		}
	}
	float mean_m = wsum > 0.0001 ? msum / wsum : 0.0;
	COLOR = vec4(clamp(mean_m * 2.0, 0.0, 1.0), clamp(wsum / float(STEPS * STEPS), 0.0, 1.0), 0.0, 1.0);
}
