shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform float amount : hint_range(-2.0, 2.0) = 0.5;
uniform float radius : hint_range(0.01, 2.0) = 0.4;
uniform vec2 tex_size;

void fragment() {
	vec2 aspect = vec2(max(tex_size.x, 1.0) / max(tex_size.y, 1.0), 1.0);
	vec2 d = (UV - centre) * aspect;
	float r = length(d);
	float rad = max(radius, 0.0001);
	vec2 src = UV;
	if (r < rad) {
		float t = r / rad;
		float k = pow(t, 1.0 + amount);
		src = centre + (d * (r > 0.0001 ? k / t : 1.0)) / aspect;
	}
	COLOR = texture(TEXTURE, clamp(src, vec2(0.0), vec2(1.0)));
}
