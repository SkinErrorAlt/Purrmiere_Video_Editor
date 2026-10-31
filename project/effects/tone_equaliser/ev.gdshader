shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec4 c = texture(effect_tex, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	float y = dot(to_linear(rgb), LUMA);
	float ev = log2(max(y, exp2(-10.0)));
	COLOR = vec4(vec3(clamp((ev + 10.0) / 10.0, 0.0, 1.0)), 1.0);
}
