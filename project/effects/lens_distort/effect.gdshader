shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float amount : hint_range(-1.0, 1.0) = 0.2;
uniform float zoom : hint_range(0.5, 2.0) = 1.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform bool edge = false;

void fragment() {
	vec2 aspect = vec2(tex_size.x / max(tex_size.y, 1.0), 1.0);
	vec2 p = (UV - centre) * aspect / max(zoom, 0.01);
	float r2 = dot(p, p);
	vec2 q = p * (1.0 + amount * r2);
	vec2 uv = q / aspect + centre;
	if (edge || (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0)) {
		COLOR = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	} else {
		COLOR = vec4(0.0);
	}
}
