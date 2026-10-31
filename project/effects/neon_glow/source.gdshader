shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);

void fragment() {
	vec2 e = 0.5 / max(tex_size, vec2(1.0));
	vec4 s = texture(TEXTURE, UV + vec2(-e.x, -e.y));
	s += texture(TEXTURE, UV + vec2(e.x, -e.y));
	s += texture(TEXTURE, UV + vec2(-e.x, e.y));
	s += texture(TEXTURE, UV + vec2(e.x, e.y));
	s *= 0.25;
	float l = dot(s.rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(l, s.a, 0.0, 1.0);
}
