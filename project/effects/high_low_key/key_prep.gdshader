shader_type canvas_item;
render_mode blend_disabled;

uniform int mode : hint_range(0, 1) = 0;
uniform float strength : hint_range(0.0, 100.0) = 70.0;
uniform float brightness : hint_range(-100.0, 100.0) = 0.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 high_key_tone(vec3 x) {
	float s = clamp(strength, 0.0, 100.0) / 100.0;
	float b = clamp(brightness, -100.0, 100.0) / 100.0;
	float lift = clamp(0.3 * s * (1.0 + 0.4 * b), 0.0, 0.6);
	float g = max(1.0 + s * (1.4 + 1.1 * b), 0.35);
	return lift + (1.0 - lift) * (1.0 - pow(max(1.0 - x, vec3(0.0)), vec3(g)));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 bright;
	if (mode == 0) {
		vec3 t = high_key_tone(rgb);
		bright = t * smoothstep(0.55, 1.0, dot(t, LUMA));
	} else {
		bright = rgb;
	}
	COLOR = vec4(bright * a, a);
}
