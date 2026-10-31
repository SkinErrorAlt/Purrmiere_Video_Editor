shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int blades : hint_range(2, 24) = 8;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float feather : hint_range(0.0, 0.2) = 0.01;
uniform bool reverse = false;
uniform vec2 tex_size;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 d = (UV - centre) * vec2(max(tex_size.x, 1.0) / max(tex_size.y, 1.0), 1.0);
	float a = atan(d.y, d.x);
	if (reverse) { a = -a; }
	float f = fract(a / 6.2831853 * float(max(blades, 1)));
	float fe = max(feather, 0.0005);
	float p = mix(-fe, 1.0, progress);
	float keep = smoothstep(p, p + fe, f);
	COLOR = c * keep;
}
