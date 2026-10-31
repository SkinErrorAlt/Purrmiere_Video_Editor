shader_type canvas_item;
render_mode blend_disabled;

uniform int shape : hint_range(0, 2) = 0;
uniform float cell_size : hint_range(8.0, 1200.0) = 240.0;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform vec2 take_from = vec2(0.5, 0.45);
uniform float turn_speed : hint_range(-360.0, 360.0) = 0.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float time = 0.0;

const float R3 = 1.7320508;

vec2 mirror_uv(vec2 uv) {
	return vec2(1.0) - abs(vec2(1.0) - mod(uv, vec2(2.0)));
}

vec2 fold(vec2 q, vec2 p0, vec2 nrm) {
	float e = dot(q - p0, nrm);
	return e < 0.0 ? q - 2.0 * e * nrm : q;
}

vec2 reduce(vec2 q, vec2 a, vec2 b) {
	mat2 m = mat2(a, b);
	vec2 c = inverse(m) * q;
	return q - m * floor(c + 0.5);
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 S = dims / ps;
	float cs = max(cell_size, 1.0);
	vec2 p = UV * S - centre * S;
	float an = radians(angle);
	p = vec2(cos(an) * p.x + sin(an) * p.y, -sin(an) * p.x + cos(an) * p.y);
	vec2 q = p / cs;
	vec2 g;
	if (shape == 1) {
		q = vec2(1.0) - abs(mod(q, vec2(2.0)) - vec2(1.0));
		g = vec2(0.5, 0.5);
	} else if (shape == 2) {
		q = reduce(q, vec2(2.0, 0.0), vec2(1.0, R3));
		for (int i = 0; i < 12; i++) {
			q = fold(q, vec2(0.0), vec2(0.0, 1.0));
			q = fold(q, vec2(1.0, 0.0), vec2(-1.0, 0.0));
			q = fold(q, vec2(0.0), vec2(0.5, -0.5 * R3));
		}
		g = vec2(2.0 / 3.0, 1.0 / (3.0 * R3));
	} else {
		q = reduce(q, vec2(1.5, 0.5 * R3), vec2(0.0, R3));
		for (int i = 0; i < 12; i++) {
			q = fold(q, vec2(0.0), vec2(0.0, 1.0));
			q = fold(q, vec2(0.0), vec2(0.5 * R3, -0.5));
			q = fold(q, vec2(1.0, 0.0), vec2(-0.5 * R3, -0.5));
		}
		g = vec2(0.5, R3 / 6.0);
	}
	vec2 l = (q - g) * cs;
	float tr = radians(turn_speed * time);
	l = vec2(cos(tr) * l.x - sin(tr) * l.y, sin(tr) * l.x + cos(tr) * l.y);
	vec2 src = take_from * S + l;
	COLOR = texture(TEXTURE, mirror_uv(src / S));
}
