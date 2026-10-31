shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 direction = vec2(1.0, 0.0);
uniform float radius = 5.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

void fragment() {
	float r = max(abs(radius) * max(px_scale, 0.0001), 0.001);
	vec2 st = direction * (r / 6.0) / max(tex_size, vec2(1.0));
	vec4 sum = vec4(0.0);
	float ws = 0.0;
	for (int i = -6; i <= 6; i++) {
		float fi = float(i);
		float w = exp(-0.5 * fi * fi / 9.0);
		sum += texture(TEXTURE, clamp(UV + st * fi, vec2(0.0), vec2(1.0))) * w;
		ws += w;
	}
	COLOR = sum / ws;
}
