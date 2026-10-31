shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 start = vec2(0.5, 0.95);
uniform vec2 end = vec2(0.5, 0.15);
uniform float bend : hint_range(-360.0, 360.0) = 40.0;
uniform int edges = 2;
uniform vec2 tex_size = vec2(1.0, 1.0);

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

void fragment() {
	vec2 aspect = vec2(max(tex_size.x, 1.0) / max(tex_size.y, 1.0), 1.0);
	vec2 axis = (end - start) * aspect;
	float len = length(axis);
	float theta = radians(bend);
	if (len < 0.0001 || abs(theta) < 0.00001) {
		COLOR = fetch(TEXTURE, UV);
	} else {
		vec2 a = axis / len;
		vec2 n = vec2(-a.y, a.x);
		vec2 q = (UV - start) * aspect;
		float s = dot(q, a);
		float w = dot(q, n);
		float sgn = theta < 0.0 ? -1.0 : 1.0;
		float th = abs(theta);
		w *= sgn;
		float s0 = s;
		float w0 = w;
		if (s > 0.0) {
			float rad = len / th;
			vec2 v = vec2(s, w - rad);
			float rho = length(v);
			float phi = atan(v.x, -v.y);
			if (phi <= th) {
				s0 = phi * rad;
				w0 = rad - rho;
			} else {
				vec2 e = vec2(rad * sin(th), rad - rad * cos(th));
				vec2 tt = vec2(cos(th), sin(th));
				vec2 nn = vec2(-sin(th), cos(th));
				vec2 o = vec2(s, w) - e;
				s0 = len + dot(o, tt);
				w0 = dot(o, nn);
			}
		}
		w0 *= sgn;
		vec2 src = start + (a * s0 + n * w0) / aspect;
		COLOR = fetch(TEXTURE, src);
	}
}
