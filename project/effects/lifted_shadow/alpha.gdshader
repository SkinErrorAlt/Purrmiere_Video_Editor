shader_type canvas_item;
render_mode blend_disabled;

uniform float shrink : hint_range(0.0, 0.5) = 0.12;

void fragment() {
	float sc = max(1.0 - shrink, 0.05);
	vec2 pc = (UV - 0.5) / sc + 0.5;
	float a = 0.0;
	if (pc.x >= 0.0 && pc.x <= 1.0 && pc.y >= 0.0 && pc.y <= 1.0) {
		a = texture(TEXTURE, pc).a;
	}
	COLOR = vec4(vec3(a), 1.0);
}
