shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float angle : hint_range(-180.0, 180.0) = 90.0;
uniform float feather : hint_range(0.0, 0.5) = 0.02;
uniform vec2 tex_size;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 d = (UV - centre) * vec2(max(tex_size.x, 1.0) / max(tex_size.y, 1.0), 1.0);
	float a = atan(-d.y, d.x) - radians(angle);
	float ad = abs(mod(a + 3.14159265, 6.2831853) - 3.14159265);
	float fe = max(feather, 0.0005);
	float p = progress * (3.14159265 + fe);
	COLOR = c * smoothstep(p - fe, p, ad);
}
