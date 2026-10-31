shader_type canvas_item;
render_mode blend_disabled;

uniform float amp_x : hint_range(0.0, 400.0) = 12.0;
uniform float wave_x : hint_range(4.0, 2000.0) = 160.0;
uniform float amp_y : hint_range(0.0, 400.0) = 12.0;
uniform float wave_y : hint_range(4.0, 2000.0) = 220.0;
uniform int shape = 0;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform float phase : hint_range(-360.0, 360.0) = 0.0;
uniform float speed : hint_range(-10.0, 10.0) = 0.0;
uniform int edges = 1;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float time;

float wave(float x) {
	float f = fract(x);
	if (shape == 1) {
		return 1.0 - 4.0 * abs(f - 0.5);
	} else if (shape == 2) {
		return clamp(sin(x * 6.28318530718) * 4.0, -1.0, 1.0);
	} else if (shape == 3) {
		return 2.0 * f - 1.0;
	}
	return sin(x * 6.28318530718);
}

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
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 p = (UV - 0.5) * dims;
	float a = radians(angle);
	vec2 ax = vec2(cos(a), sin(a));
	vec2 ay = vec2(-ax.y, ax.x);
	float u = dot(p, ax);
	float v = dot(p, ay);
	float ph = phase / 360.0 + time * speed;
	float du = amp_x * ps * wave(v / max(wave_x * ps, 1.0) + ph);
	float dv = amp_y * ps * wave(u / max(wave_y * ps, 1.0) + ph + 0.25);
	vec2 src = p + ax * du + ay * dv;
	COLOR = fetch(TEXTURE, src / dims + 0.5);
}
