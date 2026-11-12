shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform sampler2D level_tex : filter_linear, repeat_disable;
uniform float reach : hint_range(0.0, 1.0) = 0.6;

vec4 dec(vec4 c) {
	return c * c;
}

void fragment() {
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	vec4 sum = dec(texture(TEXTURE, UV)) * 4.0;
	sum += (dec(texture(TEXTURE, UV + px * vec2(-1.0, 0.0))) + dec(texture(TEXTURE, UV + px * vec2(1.0, 0.0))) + dec(texture(TEXTURE, UV + px * vec2(0.0, -1.0))) + dec(texture(TEXTURE, UV + px * vec2(0.0, 1.0)))) * 2.0;
	sum += dec(texture(TEXTURE, UV + px * vec2(-1.0, -1.0))) + dec(texture(TEXTURE, UV + px * vec2(1.0, -1.0))) + dec(texture(TEXTURE, UV + px * vec2(-1.0, 1.0))) + dec(texture(TEXTURE, UV + px * vec2(1.0, 1.0)));
	vec4 up = sum / 16.0;
	vec4 lev = dec(texture(level_tex, UV));
	float w = mix(0.4, 0.75, clamp(reach, 0.0, 1.0));
	COLOR = sqrt(clamp(mix(lev, up, w), 0.0, 1.0));
}
