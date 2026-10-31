shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D source_tex : filter_linear, repeat_disable;
uniform int mode : hint_range(0, 2) = 0;
uniform float amount : hint_range(0.0, 1.0) = 1.0;

const vec3 LUM = vec3(0.3, 0.59, 0.11);

vec3 clip_colour(vec3 c) {
	float l = dot(c, LUM);
	float n = min(c.r, min(c.g, c.b));
	float x = max(c.r, max(c.g, c.b));
	if (n < 0.0) {
		c = l + (c - l) * l / max(l - n, 0.000001);
	}
	if (x > 1.0) {
		c = l + (c - l) * (1.0 - l) / max(x - l, 0.000001);
	}
	return c;
}

vec3 set_lum(vec3 c, float l) {
	return clip_colour(c + (l - dot(c, LUM)));
}

void fragment() {
	vec4 g = texture(TEXTURE, UV);
	float a = g.a;
	vec3 graded = a > 0.0001 ? clamp(g.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec4 s = texture(source_tex, UV);
	vec3 src = s.a > 0.0001 ? clamp(s.rgb / s.a, 0.0, 1.0) : graded;
	vec3 outc;
	if (mode == 0) {
		outc = mix(graded, set_lum(src, dot(graded, LUM)), amount);
	} else if (mode == 1) {
		outc = mix(graded, set_lum(graded, dot(src, LUM)), amount);
	} else {
		outc = mix(src, graded, amount);
	}
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
