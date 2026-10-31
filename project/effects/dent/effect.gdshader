shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform float size : hint_range(0.02, 2.0) = 0.4;
uniform float strength : hint_range(-1.0, 1.0) = 0.5;
uniform int kind = 0;
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
		float s = clamp(strength, -1.0, 1.0);
		vec2 q = d;
		if (kind == 0) {
			float k = inv * inv * (3.0 - 2.0 * inv);
			q = d * max(1.0 + s * 1.6 * k * k, 0.05);
		} else if (kind == 1) {
			float k = 0.5 + 0.5 * cos(3.14159265 * t);
			q = d * max(1.0 + s * 0.7 * k, 0.05);
		} else if (kind == 2) {
			float rr = r + s * rad * 0.1 * sin(t * 18.8495559) * inv;
			q = r > 0.000001 ? d / r * max(rr, 0.0) : d;
		} else {
			float th = atan(d.y, d.x);
			float rr = r * max(1.0 + s * 0.6 * sin(6.0 * th) * inv * inv, 0.05);
			float th2 = th + s * 0.5 * sin(3.0 * th) * sin(3.14159265 * t);
			q = vec2(cos(th2), sin(th2)) * rr;
		}
		src = centre + q / aspect;
	}
	COLOR = texture(TEXTURE, clamp(src, vec2(0.0), vec2(1.0)));
}
