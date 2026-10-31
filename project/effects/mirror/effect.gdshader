shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);

void fragment() {
	float a = radians(angle);
	vec2 n = vec2(cos(a), sin(a));
	vec2 aspect = vec2(tex_size.x / max(tex_size.y, 1.0), 1.0);
	vec2 p = (UV - centre) * aspect;
	float d = dot(p, n);
	vec2 uv = UV;
	if (d > 0.0) {
		vec2 r = p - 2.0 * d * n;
		uv = r / aspect + centre;
	}
	COLOR = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
}
