shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int split : hint_range(0, 2) = 0;

void fragment() {
	vec2 q = vec2(UV.x < 0.5 ? -1.0 : 1.0, UV.y < 0.5 ? -1.0 : 1.0);
	vec2 m = split == 0 ? vec2(1.0) : (split == 1 ? vec2(1.0, 0.0) : vec2(0.0, 1.0));
	vec2 src = UV - q * m * progress * 0.5;
	bool ok = (m.x < 0.5 || (src.x - 0.5) * q.x >= 0.0) && (m.y < 0.5 || (src.y - 0.5) * q.y >= 0.0);
	COLOR = ok ? texture(TEXTURE, src) : vec4(0.0);
}
