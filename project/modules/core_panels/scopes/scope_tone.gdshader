shader_type canvas_item;

// Turns the added up points into a glowing trace: dense places bright, single points faint but visible.
uniform float gain = 1.0;

void fragment() {
	vec3 acc = texture(TEXTURE, UV).rgb * gain;
	vec3 lit = 1.0 - exp(-acc * 1.6);
	float a = clamp(max(lit.r, max(lit.g, lit.b)) * 1.4, 0.0, 1.0);
	COLOR = vec4(lit / max(a, 0.0001), a);
}
