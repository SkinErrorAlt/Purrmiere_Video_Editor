shader_type canvas_item;
render_mode blend_disabled;

uniform int trigger : hint_range(0, 2) = 0;
uniform float wobble : hint_range(0.0, 1.0) = 0.0;
uniform float amount : hint_range(0.0, 0.6) = 0.18;
uniform float frequency : hint_range(0.2, 12.0) = 3.0;
uniform float decay : hint_range(0.0, 12.0) = 3.0;
uniform float shear : hint_range(0.0, 1.0) = 0.3;
uniform int anchor : hint_range(0, 2) = 0;
uniform float clip_time;

void fragment() {
	float t = clip_time;
	float w;
	if (trigger == 0) {
		w = sin(t * frequency * 6.28318) * exp(-t * decay);
	} else if (trigger == 1) {
		w = sin(t * frequency * 6.28318);
	} else {
		w = wobble * sin(t * frequency * 6.28318);
	}
	float sy = 1.0 + amount * w;
	float sx = 1.0 / max(sy, 0.1);
	float ay = anchor == 0 ? 1.0 : (anchor == 1 ? 0.5 : 0.0);
	vec2 q = UV - vec2(0.5, ay);
	float sw = shear * amount * w * cos(t * frequency * 6.28318) * 0.5;
	q.x -= sw * (q.y);
	q /= vec2(sx, sy);
	vec2 s = q + vec2(0.5, ay);
	vec4 c = texture(TEXTURE, s);
	float inside = step(0.0, s.x) * step(s.x, 1.0) * step(0.0, s.y) * step(s.y, 1.0);
	COLOR = c * inside;
}
