shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform float start_zoom : hint_range(100.0, 400.0) = 100.0;
uniform float end_zoom : hint_range(100.0, 400.0) = 115.0;
uniform vec2 start_centre = vec2(0.5, 0.5);
uniform vec2 end_centre = vec2(0.5, 0.5);
uniform float turn : hint_range(-20.0, 20.0) = 0.0;
uniform int over : hint_range(0, 1) = 0;
uniform float seconds : hint_range(0.1, 600.0) = 5.0;
uniform int ease : hint_range(0, 3) = 0;

float eased(float x) {
	if (ease == 1) {
		return x * x * (3.0 - 2.0 * x);
	}
	if (ease == 2) {
		return 1.0 - (1.0 - x) * (1.0 - x);
	}
	if (ease == 3) {
		return x * x;
	}
	return x;
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float span = over == 1 ? max(seconds, 0.1) : max(clip_duration, 0.001);
	float e = eased(clamp(clip_time / span, 0.0, 1.0));
	float z0 = log(clamp(start_zoom, 100.0, 400.0) * 0.01);
	float z1 = log(clamp(end_zoom, 100.0, 400.0) * 0.01);
	float z = exp(mix(z0, z1, e));
	float th = radians(clamp(turn, -20.0, 20.0) * e);
	float ac = abs(cos(th));
	float as = abs(sin(th));
	float cover = max((size.x * ac + size.y * as) / size.x, (size.x * as + size.y * ac) / size.y);
	z = max(z, cover);
	vec2 half_ext = vec2(size.x * ac + size.y * as, size.x * as + size.y * ac) * 0.5 / z;
	vec2 c = mix(start_centre, end_centre, e) * size;
	c = clamp(c, half_ext, max(size - half_ext, half_ext));
	vec2 q = (UV - 0.5) * size / z;
	float cs = cos(th);
	float sn = sin(th);
	q = vec2(cs * q.x - sn * q.y, sn * q.x + cs * q.y);
	vec2 uv = (c + q) / size;
	COLOR = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
}
