shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float horizon : hint_range(0.05, 0.95) = 0.62;
uniform float threshold : hint_range(0.0, 1.0) = 0.65;

vec3 emission(vec4 c) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	float mx = max(rgb.r, max(rgb.g, rgb.b));
	float k = smoothstep(threshold, mix(threshold, 1.0, 0.6) + 0.02, mx);
	return rgb * k * k * c.a;
}

void fragment() {
	vec2 px = 0.5 / max(tex_size, vec2(1.0));
	vec3 e = emission(texture(TEXTURE, UV + vec2(-px.x, -px.y)));
	e += emission(texture(TEXTURE, UV + vec2(px.x, -px.y)));
	e += emission(texture(TEXTURE, UV + vec2(-px.x, px.y)));
	e += emission(texture(TEXTURE, UV + vec2(px.x, px.y)));
	float above = 1.0 - smoothstep(horizon - 0.004, horizon + 0.004, UV.y);
	COLOR = vec4(sqrt(clamp(e * 0.25 * above, 0.0, 1.0)), 1.0);
}
