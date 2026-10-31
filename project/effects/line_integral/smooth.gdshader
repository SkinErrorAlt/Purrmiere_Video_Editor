shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);

void fragment() {
	vec2 px = 1.5 / max(tex_size, vec2(1.0));
	vec4 s = texture(TEXTURE, UV) * 4.0;
	s += texture(TEXTURE, clamp(UV + vec2(px.x, 0.0), vec2(0.0), vec2(1.0))) * 2.0;
	s += texture(TEXTURE, clamp(UV - vec2(px.x, 0.0), vec2(0.0), vec2(1.0))) * 2.0;
	s += texture(TEXTURE, clamp(UV + vec2(0.0, px.y), vec2(0.0), vec2(1.0))) * 2.0;
	s += texture(TEXTURE, clamp(UV - vec2(0.0, px.y), vec2(0.0), vec2(1.0))) * 2.0;
	s += texture(TEXTURE, clamp(UV + px, vec2(0.0), vec2(1.0)));
	s += texture(TEXTURE, clamp(UV - px, vec2(0.0), vec2(1.0)));
	s += texture(TEXTURE, clamp(UV + vec2(px.x, -px.y), vec2(0.0), vec2(1.0)));
	s += texture(TEXTURE, clamp(UV + vec2(-px.x, px.y), vec2(0.0), vec2(1.0)));
	COLOR = vec4(s.rgb / 16.0, 1.0);
}
