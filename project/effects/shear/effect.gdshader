shader_type canvas_item;
render_mode blend_disabled;

uniform float horizontal : hint_range(-1.0, 1.0) = 0.2;
uniform float vertical : hint_range(-1.0, 1.0) = 0.0;
uniform vec2 pivot = vec2(0.5, 0.5);
uniform bool wrap = false;

void fragment() {
	vec2 d = UV - pivot;
	vec2 src = UV - vec2(d.y * horizontal, d.x * vertical);
	bool outside = src.x < 0.0 || src.x > 1.0 || src.y < 0.0 || src.y > 1.0;
	if (wrap) {
		COLOR = texture(TEXTURE, fract(src));
	} else if (outside) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, src);
	}
}
