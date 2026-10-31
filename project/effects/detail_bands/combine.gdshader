shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D g1_tex : filter_linear, repeat_disable;
uniform sampler2D g2_tex : filter_linear, repeat_disable;
uniform float fine : hint_range(-1.0, 1.0) = 0.3;
uniform float medium : hint_range(-1.0, 1.0) = 0.2;
uniform float large : hint_range(-1.0, 1.0) = 0.0;
uniform bool luma_only = true;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 straight(vec4 c, vec3 fallback) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : fallback;
}

void fragment() {
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	vec3 i0 = straight(c, vec3(0.0));
	vec3 g1 = straight(texture(g1_tex, UV), i0);
	vec3 g2 = straight(texture(g2_tex, UV), g1);
	vec3 g3 = straight(texture(TEXTURE, UV), g2);
	vec3 detail = fine * (i0 - g1) + medium * (g1 - g2) + large * (g2 - g3);
	if (luma_only) {
		detail = vec3(dot(detail, LUMA));
	}
	COLOR = vec4(clamp(i0 + detail, 0.0, 1.0) * a, a);
}
