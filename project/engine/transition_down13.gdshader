shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D src : filter_linear, repeat_disable;
uniform vec2 src_px = vec2(1.0, 1.0);
uniform bool src_canvas = false;
uniform vec4 src_map = vec4(1.0, 1.0, 0.0, 0.0);

vec4 tap(vec2 uv) {
	if (!src_canvas) {
		return texture(src, uv);
	}
	vec2 h = 0.5 / max(src_px, vec2(1.0));
	return texture(src, clamp(uv, h, 1.0 - h) * src_map.xy + src_map.zw);
}

void fragment() {
	vec2 px = 1.0 / max(src_px, vec2(1.0));
	vec2 uv = UV;
	vec4 a = tap(uv + px * vec2(-2.0, -2.0));
	vec4 b = tap(uv + px * vec2(0.0, -2.0));
	vec4 c = tap(uv + px * vec2(2.0, -2.0));
	vec4 d = tap(uv + px * vec2(-2.0, 0.0));
	vec4 e = tap(uv);
	vec4 f = tap(uv + px * vec2(2.0, 0.0));
	vec4 g = tap(uv + px * vec2(-2.0, 2.0));
	vec4 h = tap(uv + px * vec2(0.0, 2.0));
	vec4 i = tap(uv + px * vec2(2.0, 2.0));
	vec4 j = tap(uv + px * vec2(-1.0, -1.0));
	vec4 k = tap(uv + px * vec2(1.0, -1.0));
	vec4 l = tap(uv + px * vec2(-1.0, 1.0));
	vec4 m = tap(uv + px * vec2(1.0, 1.0));
	vec4 sum = (j + k + l + m) * 0.5;
	sum += (a + b + d + e) * 0.125;
	sum += (b + c + e + f) * 0.125;
	sum += (d + e + g + h) * 0.125;
	sum += (e + f + h + i) * 0.125;
	COLOR = sum * 0.25;
}
