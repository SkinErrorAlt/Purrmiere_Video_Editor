shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float zoom = 1.0;
uniform float angle = 0.0;
uniform vec2 shift = vec2(0.0, 0.0);
uniform vec2 anchor = vec2(0.5, 0.5);
uniform int edges : hint_range(0, 3) = 0;

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	vec2 p = (UV - anchor) * size;
	p -= shift * px_scale;
	float a = -radians(angle);
	float cs = cos(a);
	float sn = sin(a);
	p = vec2(cs * p.x - sn * p.y, sn * p.x + cs * p.y);
	p /= max(zoom, 0.01);
	vec2 uv = p / size + anchor;
	float valid = 1.0;
	if (edges == 1) {
		vec2 m = mod(uv, 2.0);
		uv = mix(m, 2.0 - m, step(vec2(1.0), m));
	} else if (edges == 2) {
		uv = fract(uv);
	} else if (edges == 0) {
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			valid = 0.0;
		}
	}
	COLOR = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0))) * valid;
}
