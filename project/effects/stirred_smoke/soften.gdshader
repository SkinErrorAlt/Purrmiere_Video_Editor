shader_type canvas_item;
render_mode blend_disabled;

uniform float spread = 1.0;

void fragment() {
	vec2 px = 1.0 / vec2(textureSize(TEXTURE, 0));
	vec4 acc = texture(TEXTURE, UV) * 0.2;
	for (int k = 0; k < 8; k++) {
		float a = float(k) * 0.785398 + 0.2;
		acc += texture(TEXTURE, UV + vec2(cos(a), sin(a)) * px * 1.6 * spread) * 0.1;
	}
	COLOR = acc;
}
