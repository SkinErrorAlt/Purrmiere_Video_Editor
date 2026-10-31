shader_type canvas_item;
render_mode blend_disabled;

uniform float zoom : hint_range(10.0, 1000.0) = 130.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float turn : hint_range(-180.0, 180.0) = 0.0;
uniform float blur : hint_range(0.0, 1.0) = 0.0;
uniform int edges : hint_range(0, 2) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);

vec2 wrap(vec2 uv) {
	if (edges == 1) {
		return fract(uv);
	}
	vec2 m = mod(uv, 2.0);
	return clamp(mix(m, 2.0 - m, step(vec2(1.0), m)), vec2(0.0), vec2(1.0));
}

float inside(vec2 uv) {
	if (edges != 2) {
		return 1.0;
	}
	return (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) ? 0.0 : 1.0;
}

vec2 mapped(vec2 uv, float s) {
	float asp = max(tex_size.x, 1.0) / max(tex_size.y, 1.0);
	vec2 p = uv - centre;
	p.x *= asp;
	float a = radians(-turn);
	p = vec2(cos(a) * p.x - sin(a) * p.y, sin(a) * p.x + cos(a) * p.y) / s;
	p.x /= asp;
	return centre + p;
}

void fragment() {
	float s = max(zoom, 1.0) / 100.0;
	float b = clamp(blur, 0.0, 1.0);
	if (b <= 0.001) {
		vec2 uv = mapped(UV, s);
		COLOR = texture(TEXTURE, wrap(uv)) * inside(uv);
	} else {
		vec4 sum = vec4(0.0);
		for (int i = 0; i < 12; i++) {
			float k = float(i) / 11.0;
			vec2 uv = mapped(UV, s * (1.0 + b * 0.18 * k));
			sum += texture(TEXTURE, wrap(uv)) * inside(uv);
		}
		COLOR = sum / 12.0;
	}
}
