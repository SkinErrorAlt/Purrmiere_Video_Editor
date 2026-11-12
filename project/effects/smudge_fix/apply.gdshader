shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float strength : hint_range(0.0, 0.8) = 0.3;
uniform float lights_only : hint_range(0.0, 1.0) = 0.4;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_display(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 source_of(vec3 lin) {
	float t0 = clamp(lights_only, 0.0, 1.0) * 0.55;
	float w = t0 <= 0.0005 ? 1.0 : smoothstep(t0, t0 + 0.3, dot(lin, LUMA));
	return lin * w;
}

void fragment() {
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	vec3 lin = to_linear(a > 0.0001 ? c.rgb / a : vec3(0.0));
	vec3 glow = to_linear(texture(TEXTURE, UV).rgb);
	float k = clamp(strength, 0.0, 0.8);
	vec3 clean = lin - k * glow + k * source_of(lin);
	vec3 floor_v = lin * 0.12;
	clean = max(clean, floor_v);
	COLOR = vec4(to_display(clean) * a, a);
}
