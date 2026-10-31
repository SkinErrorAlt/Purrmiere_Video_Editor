shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int direction : hint_range(0, 3) = 0;
uniform float smear : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec2 q = UV;
	if (direction == 1) { q.x = 1.0 - q.x; }
	if (direction >= 2) { q = q.yx; }
	if (direction == 3) { q.x = 1.0 - q.x; }
	float p = clamp(progress, 0.0, 0.9999);
	vec2 s = q;
	float a = 1.0;
	if (q.x >= p) {
		s.x = (q.x - p) / (1.0 - p);
	} else {
		s.x = 0.0;
		a = smear * pow(q.x / max(p, 0.0001), 2.0) * (1.0 - progress);
	}
	if (direction == 3) { s.x = 1.0 - s.x; }
	if (direction >= 2) { s = s.yx; }
	if (direction == 1) { s.x = 1.0 - s.x; }
	COLOR = texture(TEXTURE, s) * a;
}
