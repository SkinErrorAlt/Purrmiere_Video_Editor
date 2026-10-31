shader_type canvas_item;
render_mode blend_disabled;

uniform int style : hint_range(0, 10) = 0;
uniform float bend : hint_range(-1.0, 1.0) = 0.5;
uniform float h_distort : hint_range(-1.0, 1.0) = 0.0;
uniform float v_distort : hint_range(-1.0, 1.0) = 0.0;
uniform bool vertical = false;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	if (vertical) { p = p.yx; }
	float b = bend;
	float x = p.x;
	float y = p.y;
	vec2 s = p;
	if (style == 0) {
		s.y = y + b * 0.5 * (1.0 - x * x) * (1.0 - 0.5 * y);
	} else if (style == 1) {
		s.y = y + b * 0.45 * (1.0 - x * x);
	} else if (style == 2) {
		s.y = y * (1.0 - b * 0.5 * (1.0 - x * x));
	} else if (style == 3) {
		s.y = y + b * 0.6 * (1.0 - x * x) * (0.5 + 0.5 * y);
	} else if (style == 4) {
		s.y = y - b * 0.6 * (1.0 - x * x) * (0.5 - 0.5 * y);
	} else if (style == 5) {
		s.y = y - b * 0.3 * sin(x * 3.14159265);
	} else if (style == 6) {
		s.y = y - b * 0.2 * sin(x * 6.2831853) * (1.0 - 0.3 * y);
	} else if (style == 7) {
		s.y = y + b * 0.4 * sin(x * 1.5707963);
	} else if (style == 8) {
		s.x = x * (1.0 + b * 0.6 * (1.0 - y * y));
		s.y = y * (1.0 - b * 0.3 * (1.0 - x * x));
	} else if (style == 9) {
		float r2 = min(dot(p, p), 2.0);
		s = p * (1.0 - b * 0.4 * (1.0 - r2 * 0.5));
	} else {
		float r = length(p);
		float a = b * 3.14159265 * max(1.0 - r, 0.0);
		s = vec2(cos(a) * x - sin(a) * y, sin(a) * x + cos(a) * y);
	}
	s.y *= 1.0 + h_distort * 0.5 * s.x;
	s.x *= 1.0 + v_distort * 0.5 * s.y;
	if (vertical) { s = s.yx; }
	vec2 uv = s * 0.5 + 0.5;
	bool outside = uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0;
	COLOR = outside ? vec4(0.0) : texture(TEXTURE, uv);
}
