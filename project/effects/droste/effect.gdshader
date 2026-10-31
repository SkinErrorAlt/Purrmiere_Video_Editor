shader_type canvas_item;
render_mode blend_disabled;

uniform float ratio : hint_range(0.1, 0.9) = 0.5;
uniform float zoom : hint_range(0.0, 1.0) = 0.0;
uniform float twist : hint_range(-180.0, 180.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform vec2 tex_size;

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	vec2 asp = vec2(sz.x / sz.y, 1.0);
	vec2 p = (UV - centre) * asp;
	float lr = log(clamp(ratio, 0.1, 0.9));
	p *= exp(lr * zoom);
	float s = max(abs(p.x) / (0.5 * asp.x), abs(p.y) * 2.0);
	float lev = s > 0.000001 ? log(s) / lr : 30.0;
	float n = max(floor(lev), 0.0);
	vec2 q = p / exp(lr * n);
	float tw = radians(twist) * lev;
	q = vec2(cos(tw) * q.x - sin(tw) * q.y, sin(tw) * q.x + cos(tw) * q.y);
	vec2 uv = 0.5 + q / asp;
	bool outside = uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0;
	COLOR = outside ? vec4(0.0) : texture(TEXTURE, uv);
}
