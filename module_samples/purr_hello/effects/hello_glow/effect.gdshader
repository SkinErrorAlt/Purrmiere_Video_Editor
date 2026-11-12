shader_type canvas_item;
render_mode blend_disabled;

uniform float amount : hint_range(0.0, 1.0) = 0.5;
uniform float warmth : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec2 px = TEXTURE_PIXEL_SIZE * 6.0;
	vec3 soft = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = 6.2831853 * float(i) / 8.0;
		vec4 s = texture(TEXTURE, UV + vec2(cos(a), sin(a)) * px);
		soft += s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
	}
	soft /= 8.0;
	vec3 tint = mix(vec3(1.0), vec3(1.08, 0.98, 0.86), warmth);
	vec3 glow = 1.0 - (1.0 - rgb) * (1.0 - soft * tint * amount);
	COLOR = vec4(clamp(glow, 0.0, 1.0) * c.a, c.a);
}
