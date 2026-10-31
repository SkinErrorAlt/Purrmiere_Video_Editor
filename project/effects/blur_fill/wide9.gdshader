shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform vec2 direction = vec2(1.0, 0.0);

void fragment() {
	vec2 st = direction / max(tex_size, vec2(1.0));
	vec4 s = texture(TEXTURE, UV) * 0.1597;
	s += (texture(TEXTURE, UV + st * 1.4403) + texture(TEXTURE, UV - st * 1.4403)) * 0.26335;
	s += (texture(TEXTURE, UV + st * 3.3635) + texture(TEXTURE, UV - st * 3.3635)) * 0.12213;
	s += (texture(TEXTURE, UV + st * 5.293) + texture(TEXTURE, UV - st * 5.293)) * 0.03056;
	s += (texture(TEXTURE, UV + st * 7.233) + texture(TEXTURE, UV - st * 7.233)) * 0.00412;
	COLOR = s;
}
