shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

void fragment() {
	vec2 e = vec2(1.6 * max(px_scale, 0.0001)) / max(tex_size, vec2(1.0));
	vec4 s = texture(TEXTURE, UV) * 4.0;
	s += texture(TEXTURE, clamp(UV + vec2(e.x, 0.0), vec2(0.0), vec2(1.0))) * 2.0;
	s += texture(TEXTURE, clamp(UV - vec2(e.x, 0.0), vec2(0.0), vec2(1.0))) * 2.0;
	s += texture(TEXTURE, clamp(UV + vec2(0.0, e.y), vec2(0.0), vec2(1.0))) * 2.0;
	s += texture(TEXTURE, clamp(UV - vec2(0.0, e.y), vec2(0.0), vec2(1.0))) * 2.0;
	s += texture(TEXTURE, clamp(UV + e, vec2(0.0), vec2(1.0)));
	s += texture(TEXTURE, clamp(UV - e, vec2(0.0), vec2(1.0)));
	s += texture(TEXTURE, clamp(UV + vec2(e.x, -e.y), vec2(0.0), vec2(1.0)));
	s += texture(TEXTURE, clamp(UV + vec2(-e.x, e.y), vec2(0.0), vec2(1.0)));
	s /= 16.0;
	float l = dot(s.rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(l, s.a, 0.0, 1.0);
}
