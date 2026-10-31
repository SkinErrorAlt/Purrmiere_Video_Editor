shader_type canvas_item;
render_mode blend_disabled;

uniform float shift : hint_range(0.0, 200.0) = 6.0;
uniform int copies : hint_range(2, 8) = 4;
uniform float angle : hint_range(-180.0, 180.0) = 45.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float d = max(shift, 0.0) * max(px_scale, 0.0001);
	int n = clamp(copies, 2, 8);
	vec4 sum = vec4(0.0);
	for (int i = 0; i < 8; i++) {
		if (i >= n) {
			break;
		}
		float a = radians(angle) + 6.28318530718 * float(i) / float(n);
		vec2 off = vec2(cos(a), sin(a)) * d / dims;
		sum += texture(TEXTURE, clamp(UV + off, vec2(0.0), vec2(1.0)));
	}
	COLOR = sum / float(n);
}
