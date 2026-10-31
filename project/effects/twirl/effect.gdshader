shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform float angle : hint_range(-1080.0, 1080.0) = 180.0;
uniform float radius : hint_range(0.01, 2.0) = 0.45;
uniform float softness : hint_range(0.0, 1.0) = 0.5;
uniform vec2 tex_size;

void fragment() {
	vec2 aspect = vec2(max(tex_size.x, 1.0) / max(tex_size.y, 1.0), 1.0);
	vec2 d = (UV - centre) * aspect;
	float r = length(d);
	float t = clamp(1.0 - r / max(radius, 0.0001), 0.0, 1.0);
	t = mix(t, t * t * (3.0 - 2.0 * t), softness);
	float turn = radians(angle) * t;
	float cs = cos(turn);
	float sn = sin(turn);
	vec2 rot = vec2(d.x * cs - d.y * sn, d.x * sn + d.y * cs);
	vec2 src = centre + rot / aspect;
	COLOR = texture(TEXTURE, clamp(src, vec2(0.0), vec2(1.0)));
}
