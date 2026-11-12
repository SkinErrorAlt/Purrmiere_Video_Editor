shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 top_left = vec2(0.0, 0.0);
uniform vec2 top_right = vec2(1.0, 0.0);
uniform vec2 bottom_right = vec2(1.0, 1.0);
uniform vec2 bottom_left = vec2(0.0, 1.0);
uniform int steps : hint_range(4, 32) = 12;

mat3 square_to_quad(vec2 p0, vec2 p1, vec2 p2, vec2 p3) {
	vec2 d1 = p1 - p2;
	vec2 d2 = p3 - p2;
	vec2 d3 = p0 - p1 + p2 - p3;
	float g = 0.0;
	float h = 0.0;
	float den = d1.x * d2.y - d2.x * d1.y;
	if (abs(d3.x) > 0.0000001 || abs(d3.y) > 0.0000001) {
		if (abs(den) > 0.0000001) {
			g = (d3.x * d2.y - d2.x * d3.y) / den;
			h = (d1.x * d3.y - d3.x * d1.y) / den;
		}
	}
	float a = p1.x - p0.x + g * p1.x;
	float b = p3.x - p0.x + h * p3.x;
	float d = p1.y - p0.y + g * p1.y;
	float e = p3.y - p0.y + h * p3.y;
	return mat3(vec3(a, d, g), vec3(b, e, h), vec3(p0.x, p0.y, 1.0));
}

void fragment() {
	mat3 m = square_to_quad(top_left, top_right, bottom_right, bottom_left);
	float det = determinant(m);
	if (abs(det) < 0.000000001) {
		COLOR = vec4(0.0);
	} else {
		vec3 h = inverse(m) * vec3(UV, 1.0);
		vec2 st = h.xy / h.z;
		vec3 back = m * vec3(st, 1.0);
		vec2 fw = max(fwidth(st), vec2(0.000001));
		vec2 inside = min(st / fw, (1.0 - st) / fw);
		float cover = clamp(min(inside.x, inside.y) + 0.5, 0.0, 1.0);
		if (back.z <= 0.0 || abs(h.z) < 0.0000001) {
			cover = 0.0;
		}
		COLOR = texture(TEXTURE, clamp(st, vec2(0.0), vec2(1.0))) * cover;
	}
}
