shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);

vec3 dec(vec4 c) {
	return c.rgb * c.rgb;
}

void fragment() {
	vec2 px = 0.5 / max(tex_size, vec2(1.0));
	vec3 s = dec(texture(TEXTURE, UV + vec2(-px.x, -px.y))) + dec(texture(TEXTURE, UV + vec2(px.x, -px.y))) + dec(texture(TEXTURE, UV + vec2(-px.x, px.y))) + dec(texture(TEXTURE, UV + vec2(px.x, px.y)));
	COLOR = vec4(sqrt(clamp(s * 0.25, 0.0, 1.0)), 1.0);
}
