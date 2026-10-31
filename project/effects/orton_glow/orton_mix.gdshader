shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float brightness : hint_range(0.0, 3.0) = 1.5;
uniform float glow : hint_range(0.0, 1.0) = 0.8;
uniform int mode : hint_range(0, 2) = 0;
uniform float saturation : hint_range(0.0, 2.0) = 1.15;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 sharp = 1.0 - pow(1.0 - rgb, vec3(1.0 + max(brightness, 0.0)));
	vec4 b = texture(TEXTURE, UV);
	vec3 soft = b.a > 0.0001 ? clamp(b.rgb / b.a, 0.0, 1.0) : vec3(0.0);
	vec3 layer = mix(sharp, soft, clamp(glow, 0.0, 1.0));
	vec3 outc;
	if (mode == 1) {
		outc = mix(2.0 * rgb * layer + rgb * rgb * (1.0 - 2.0 * layer), sqrt(rgb) * (2.0 * layer - 1.0) + 2.0 * rgb * (1.0 - layer), step(0.5, layer));
	} else if (mode == 2) {
		outc = 1.0 - (1.0 - rgb) * (1.0 - layer * vec3(0.85));
	} else {
		outc = sharp * layer;
	}
	float l = dot(outc, LUMA);
	outc = mix(vec3(l), outc, max(saturation, 0.0));
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
