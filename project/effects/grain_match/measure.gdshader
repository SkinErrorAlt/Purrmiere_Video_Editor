shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_nearest, repeat_disable;
uniform sampler2D reference : filter_nearest, repeat_disable, hint_default_transparent;
uniform bool from_ref = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec4 pixel_at(ivec2 p, ivec2 size) {
	ivec2 q = clamp(p, ivec2(0), size - 1);
	vec4 s = from_ref ? texelFetch(reference, q, 0) : texelFetch(effect_tex, q, 0);
	return s.a > 0.0001 ? vec4(clamp(s.rgb / s.a, 0.0, 1.0), s.a) : vec4(0.0);
}

void fragment() {
	ivec2 size = from_ref ? textureSize(reference, 0) : textureSize(effect_tex, 0);
	ivec2 base = ivec2(floor(UV * vec2(size))) - ivec2(2);
	float l[36];
	vec3 lo = vec3(1.0);
	vec3 hi = vec3(0.0);
	float alpha = 1.0;
	for (int j = 0; j < 6; j++) {
		for (int i = 0; i < 6; i++) {
			vec4 px = pixel_at(base + ivec2(i, j), size);
			l[j * 6 + i] = dot(px.rgb, LUMA);
			lo = min(lo, px.rgb);
			hi = max(hi, px.rgb);
			alpha = min(alpha, px.a);
		}
	}
	float acc = 0.0;
	for (int j = 1; j < 5; j++) {
		for (int i = 1; i < 5; i++) {
			int k = j * 6 + i;
			float n = 4.0 * l[k] - 2.0 * (l[k - 1] + l[k + 1] + l[k - 6] + l[k + 6]) + l[k - 7] + l[k - 5] + l[k + 5] + l[k + 7];
			acc += abs(n);
		}
	}
	bool clipped = min(lo.r, min(lo.g, lo.b)) < 0.004 || max(hi.r, max(hi.g, hi.b)) > 0.996;
	float valid = (size.x > 4 && size.y > 4 && alpha > 0.01 && !clipped) ? 1.0 : 0.0;
	COLOR = vec4(clamp(acc / 16.0 * 2.5, 0.0, 1.0), valid, 0.0, 1.0);
}
