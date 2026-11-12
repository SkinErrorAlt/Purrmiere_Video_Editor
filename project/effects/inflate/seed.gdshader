shader_type canvas_item;
render_mode blend_disabled;

uniform int shape_from = 1;
uniform float threshold : hint_range(0.0, 1.0) = 0.5;
uniform vec2 tex_size = vec2(1.0, 1.0);

float inside(sampler2D t, vec2 uv, vec2 px) {
	vec4 c = texture(t, uv + px * vec2(-0.5, -0.5)) + texture(t, uv + px * vec2(0.5, -0.5)) + texture(t, uv + px * vec2(-0.5, 0.5)) + texture(t, uv + px * vec2(0.5, 0.5));
	c *= 0.25;
	float a = max(c.a, 0.0001);
	float l = dot(clamp(c.rgb / a, 0.0, 1.0), vec3(0.2126, 0.7152, 0.0722));
	float m = c.a;
	if (shape_from == 1) {
		m = l * c.a;
	} else if (shape_from == 2) {
		m = (1.0 - l) * c.a;
	}
	float th = shape_from == 0 ? 0.5 : threshold;
	return m > th ? 1.0 : 0.0;
}

vec4 pack2(vec2 v) {
	vec2 hi = floor(v / 256.0);
	vec2 lo = v - hi * 256.0;
	return vec4(hi.x / 255.0, lo.x / 255.0, hi.y / 255.0, lo.y / 255.0);
}

void fragment() {
	vec2 full = max(tex_size, vec2(1.0));
	vec2 qpx = SCREEN_PIXEL_SIZE;
	vec2 fpx = 2.0 / full;
	float here = inside(TEXTURE, UV, fpx);
	float edge = 0.0;
	if (here > 0.5) {
		float n = inside(TEXTURE, UV + vec2(qpx.x, 0.0), fpx) * inside(TEXTURE, UV - vec2(qpx.x, 0.0), fpx) * inside(TEXTURE, UV + vec2(0.0, qpx.y), fpx) * inside(TEXTURE, UV - vec2(0.0, qpx.y), fpx);
		if (UV.x < qpx.x || UV.y < qpx.y || UV.x > 1.0 - qpx.x || UV.y > 1.0 - qpx.y) {
			n = 0.0;
		}
		edge = 1.0 - n;
	}
	vec2 cell = floor(FRAGCOORD.xy);
	COLOR = edge > 0.5 ? pack2(cell) : vec4(1.0);
}
