shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float gain = 1.0;

void fragment() {
	vec2 px = 1.0 / tex_size;
	vec4 a = texture(TEXTURE, UV + px * vec2(-2.0, -2.0));
	vec4 b = texture(TEXTURE, UV + px * vec2(0.0, -2.0));
	vec4 c = texture(TEXTURE, UV + px * vec2(2.0, -2.0));
	vec4 d = texture(TEXTURE, UV + px * vec2(-2.0, 0.0));
	vec4 e = texture(TEXTURE, UV);
	vec4 f = texture(TEXTURE, UV + px * vec2(2.0, 0.0));
	vec4 g = texture(TEXTURE, UV + px * vec2(-2.0, 2.0));
	vec4 h = texture(TEXTURE, UV + px * vec2(0.0, 2.0));
	vec4 i = texture(TEXTURE, UV + px * vec2(2.0, 2.0));
	vec4 j = texture(TEXTURE, UV + px * vec2(-1.0, -1.0));
	vec4 k = texture(TEXTURE, UV + px * vec2(1.0, -1.0));
	vec4 l = texture(TEXTURE, UV + px * vec2(-1.0, 1.0));
	vec4 m = texture(TEXTURE, UV + px * vec2(1.0, 1.0));
	vec4 sum = (j + k + l + m) * 0.5;
	sum += (a + b + d + e) * 0.125;
	sum += (b + c + e + f) * 0.125;
	sum += (d + e + g + h) * 0.125;
	sum += (e + f + h + i) * 0.125;
	COLOR = vec4(clamp(sum.rgb * 0.25 * gain, 0.0, 1.0), 1.0);
}
