shader_type canvas_item;
render_mode blend_disabled;

uniform float hue : hint_range(-180.0, 180.0) = 0.0;
uniform float saturation : hint_range(0.0, 3.0) = 1.0;
uniform float lightness : hint_range(-1.0, 1.0) = 0.0;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

vec3 rotate_hue(vec3 c, float a) {
	vec3 k = vec3(0.57735);
	float cs = cos(a);
	float sn = sin(a);
	return c * cs + cross(k, c) * sn + k * dot(k, c) * (1.0 - cs);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	rgb = rotate_hue(rgb, radians(hue));
	float l = dot(rgb, LUMA);
	rgb = mix(vec3(l), rgb, saturation);
	rgb += lightness;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * c.a, c.a);
}
