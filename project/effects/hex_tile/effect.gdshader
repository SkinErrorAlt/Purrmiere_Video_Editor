shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform float radius : hint_range(4.0, 1000.0) = 140.0;
uniform float rotate : hint_range(-180.0, 180.0) = 0.0;
uniform int contents = 0;
uniform float smearing : hint_range(0.0, 1.0) = 0.0;
uniform int edges = 1;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

vec4 fetch(sampler2D tex, vec2 uv) {
	if (edges == 1) {
		uv = 1.0 - abs(1.0 - mod(uv, 2.0));
	} else if (edges == 2) {
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			return vec4(0.0);
		}
	}
	return texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
}

vec2 turn(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float rad = max(radius * max(px_scale, 0.0001), 1.0);
	float a = radians(rotate);
	vec2 cpx = centre * dims;
	vec2 p = turn(UV * dims - cpx, -a);
	float fq = (0.57735026919 * p.x - 0.33333333333 * p.y) / rad;
	float fr = (0.66666666667 * p.y) / rad;
	float fs = -fq - fr;
	float q = round(fq);
	float r = round(fr);
	float s = round(fs);
	float dq = abs(q - fq);
	float dr = abs(r - fr);
	float ds = abs(s - fs);
	if (dq > dr && dq > ds) {
		q = -r - s;
	} else if (dr > ds) {
		r = -q - s;
	}
	vec2 hc = rad * vec2(1.73205080757 * q + 0.86602540378 * r, 1.5 * r);
	vec2 l = p - hc;
	if (contents == 1 && mod(q, 2.0) > 0.5) {
		l.x = -l.x;
	}
	if (contents == 1 && mod(r, 2.0) > 0.5) {
		l.y = -l.y;
	}
	float sm = clamp(smearing, 0.0, 1.0);
	if (sm > 0.0) {
		float k = clamp(length(l) / rad, 0.0, 1.0);
		l *= 1.0 - sm * 0.85 * k * (1.0 - 0.5 * k);
	}
	vec2 src = cpx + turn(l, a);
	COLOR = fetch(TEXTURE, src / dims);
}
