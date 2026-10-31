shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D src : filter_linear, repeat_disable;
uniform vec2 src_px = vec2(1.0, 1.0);

void fragment() {
	vec2 px = 1.0 / max(src_px, vec2(1.0));
	vec2 uv = UV;
	vec4 a = texture(src, uv + px * vec2(-2.0, -2.0));
	vec4 b = texture(src, uv + px * vec2(0.0, -2.0));
	vec4 c = texture(src, uv + px * vec2(2.0, -2.0));
	vec4 d = texture(src, uv + px * vec2(-2.0, 0.0));
	vec4 e = texture(src, uv);
	vec4 f = texture(src, uv + px * vec2(2.0, 0.0));
	vec4 g = texture(src, uv + px * vec2(-2.0, 2.0));
	vec4 h = texture(src, uv + px * vec2(0.0, 2.0));
	vec4 i = texture(src, uv + px * vec2(2.0, 2.0));
	vec4 j = texture(src, uv + px * vec2(-1.0, -1.0));
	vec4 k = texture(src, uv + px * vec2(1.0, -1.0));
	vec4 l = texture(src, uv + px * vec2(-1.0, 1.0));
	vec4 m = texture(src, uv + px * vec2(1.0, 1.0));
	vec4 sum = (j + k + l + m) * 0.5;
	sum += (a + b + d + e) * 0.125;
	sum += (b + c + e + f) * 0.125;
	sum += (d + e + g + h) * 0.125;
	sum += (e + f + h + i) * 0.125;
	COLOR = sum * 0.25;
}
