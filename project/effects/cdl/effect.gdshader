shader_type canvas_item;
render_mode blend_disabled;

uniform vec3 slope = vec3(1.0, 1.0, 1.0);
uniform vec3 offset = vec3(0.0, 0.0, 0.0);
uniform vec3 power = vec3(1.0, 1.0, 1.0);
uniform float saturation : hint_range(0.0, 4.0) = 1.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 v = clamp(rgb * slope + offset, 0.0, 1.0);
	v = pow(v, max(power, vec3(0.01)));
	float l = dot(v, LUMA);
	v = vec3(l) + (v - vec3(l)) * saturation;
	COLOR = vec4(clamp(v, 0.0, 1.0) * a, a);
}
