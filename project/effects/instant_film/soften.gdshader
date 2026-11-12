shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

void fragment() {
	vec2 texel = 1.0 / max(tex_size, vec2(1.0));
	float r = 3.0 * max(px_scale, 0.0001);
	vec4 sum = texture(TEXTURE, UV) * 0.16;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398 + 0.2;
		vec2 d = vec2(cos(a), sin(a)) * texel * r;
		sum += texture(TEXTURE, UV + d) * 0.065;
		sum += texture(TEXTURE, UV + vec2(-d.y, d.x) * 2.1) * 0.04;
	}
	COLOR = sum;
}
