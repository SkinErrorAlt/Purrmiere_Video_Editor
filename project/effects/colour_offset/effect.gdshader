shader_type canvas_item;
render_mode blend_disabled;

uniform float red_phase : hint_range(-360.0, 360.0) = 60.0;
uniform float green_phase : hint_range(-360.0, 360.0) = 0.0;
uniform float blue_phase : hint_range(-360.0, 360.0) = -60.0;
uniform int overflow : hint_range(0, 2) = 0;

vec3 fold(vec3 x) {
	if (overflow == 1) {
		vec3 s = mod(x, 2.0);
		return mix(s, 2.0 - s, step(1.0, s));
	}
	if (overflow == 2) {
		vec3 s = mod(x, 2.0);
		return 0.5 - 0.5 * cos(3.14159265 * s);
	}
	return fract(x);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 v = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 shifted = v + vec3(red_phase, green_phase, blue_phase) / 360.0;
	COLOR = vec4(clamp(fold(shifted), 0.0, 1.0) * a, a);
}
