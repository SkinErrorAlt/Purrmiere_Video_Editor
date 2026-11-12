shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);

vec4 dec(vec4 c) {
	return c * c;
}

void fragment() {
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	vec4 sum = (dec(texture(TEXTURE, UV + px * vec2(-1.0, -1.0))) + dec(texture(TEXTURE, UV + px * vec2(1.0, -1.0))) + dec(texture(TEXTURE, UV + px * vec2(-1.0, 1.0))) + dec(texture(TEXTURE, UV + px * vec2(1.0, 1.0)))) * 0.125;
	sum += dec(texture(TEXTURE, UV)) * 0.125;
	sum += (dec(texture(TEXTURE, UV + px * vec2(-2.0, 0.0))) + dec(texture(TEXTURE, UV + px * vec2(2.0, 0.0))) + dec(texture(TEXTURE, UV + px * vec2(0.0, -2.0))) + dec(texture(TEXTURE, UV + px * vec2(0.0, 2.0)))) * 0.0625;
	sum += (dec(texture(TEXTURE, UV + px * vec2(-2.0, -2.0))) + dec(texture(TEXTURE, UV + px * vec2(2.0, -2.0))) + dec(texture(TEXTURE, UV + px * vec2(-2.0, 2.0))) + dec(texture(TEXTURE, UV + px * vec2(2.0, 2.0)))) * 0.03125;
	COLOR = sqrt(clamp(sum, 0.0, 1.0));
}
