shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform float black_mist : hint_range(0.0, 1.0) = 0.0;
uniform float warmth : hint_range(-1.0, 1.0) = 0.2;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec4 o = texture(effect_tex, UV);
	float a = o.a;
	vec3 rgb = a > 0.0001 ? o.rgb / a : vec3(0.0);
	vec4 g = texture(TEXTURE, UV);
	vec3 warm = vec3(1.0 + 0.12 * warmth, 1.0 + 0.02 * warmth, 1.0 - 0.18 * warmth);
	vec3 veil = clamp(g.rgb * warm, 0.0, 1.0);
	float s = clamp(strength, 0.0, 1.0);
	vec3 pro = 1.0 - (1.0 - rgb) * (1.0 - veil * s);
	float dark = 1.0 - smoothstep(0.0, 0.7, dot(rgb, LUMA));
	vec3 soft = mix(rgb, veil, s * mix(0.3, 0.6, dark));
	soft = 1.0 - (1.0 - soft) * (1.0 - veil * s * 0.15);
	vec3 outc = mix(pro, soft, clamp(black_mist, 0.0, 1.0));
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
