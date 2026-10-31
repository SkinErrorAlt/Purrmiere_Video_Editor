shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform float strength : hint_range(-100.0, 100.0) = 30.0;
uniform int ridges : hint_range(1, 20) = 5;
uniform int style = 2;
uniform float radius : hint_range(0.02, 2.0) = 0.6;
uniform vec2 tex_size = vec2(1.0, 1.0);

vec2 turn(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

void fragment() {
	vec2 aspect = vec2(max(tex_size.x, 1.0) / max(tex_size.y, 1.0), 1.0);
	vec2 d = (UV - centre) * aspect;
	float r = length(d);
	float rad = max(radius, 0.0001);
	vec2 src = UV;
	if (r < rad && r > 0.000001) {
		float t = r / rad;
		float fall = 1.0 - t;
		fall = fall * fall * (3.0 - 2.0 * fall);
		float k = clamp(strength / 100.0, -1.0, 1.0);
		float n = float(max(ridges, 1));
		float wave = sin(t * n * 6.28318530718) * k * fall;
		vec2 dir = d / r;
		vec2 q = d;
		if (style == 0) {
			q = turn(d, wave * 0.5);
		} else if (style == 1) {
			q = dir * max(r + wave * rad * 0.35 / n, 0.0);
		} else {
			q = turn(dir * max(r + wave * rad * 0.25 / n, 0.0), wave * 0.3);
		}
		src = centre + q / aspect;
	}
	COLOR = texture(TEXTURE, clamp(src, vec2(0.0), vec2(1.0)));
}
