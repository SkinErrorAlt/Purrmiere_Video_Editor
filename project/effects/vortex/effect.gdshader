shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform float size : hint_range(0.02, 2.0) = 0.5;
uniform float spin : hint_range(-1080.0, 1080.0) = 360.0;
uniform float pull : hint_range(0.0, 1.0) = 0.2;
uniform vec2 tex_size = vec2(1.0, 1.0);

void fragment() {
	vec2 aspect = vec2(max(tex_size.x, 1.0) / max(tex_size.y, 1.0), 1.0);
	vec2 d = (UV - centre) * aspect;
	float r = length(d);
	float rad = max(size, 0.0001);
	vec2 src = UV;
	if (r < rad) {
		float t = r / rad;
		float inv = 1.0 - t;
		float k = inv * inv * (0.3 / (t + 0.3));
		float a = radians(spin) * k;
		float cs = cos(a);
		float sn = sin(a);
		vec2 q = vec2(d.x * cs - d.y * sn, d.x * sn + d.y * cs);
		q *= 1.0 + clamp(pull, 0.0, 1.0) * 1.5 * inv * inv;
		src = centre + q / aspect;
	}
	COLOR = texture(TEXTURE, clamp(src, vec2(0.0), vec2(1.0)));
}
