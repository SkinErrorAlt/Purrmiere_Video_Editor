shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform float smear : hint_range(0.0, 1.0) = 1.0;
uniform bool both_sides = false;
uniform vec2 tex_size = vec2(1.0, 1.0);

void fragment() {
	vec2 aspect = vec2(max(tex_size.x, 1.0) / max(tex_size.y, 1.0), 1.0);
	vec2 d = (UV - centre) * aspect;
	float a = radians(angle);
	vec2 n = vec2(cos(a), sin(a));
	float s = dot(d, n);
	vec2 q = d;
	if (s > 0.0 || both_sides) {
		q = d - n * s * clamp(smear, 0.0, 1.0);
	}
	COLOR = texture(TEXTURE, clamp(centre + q / aspect, vec2(0.0), vec2(1.0)));
}
