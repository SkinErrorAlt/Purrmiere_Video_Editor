shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float threshold : hint_range(0.0, 1.0) = 0.55;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec2 px = 0.5 / max(tex_size, vec2(1.0));
	vec4 s = texture(TEXTURE, UV + vec2(-px.x, -px.y)) + texture(TEXTURE, UV + vec2(px.x, -px.y)) + texture(TEXTURE, UV + vec2(-px.x, px.y)) + texture(TEXTURE, UV + vec2(px.x, px.y));
	s *= 0.25;
	vec3 rgb = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
	float y = dot(rgb, LUMA);
	float k = smoothstep(threshold, min(threshold + 0.3, 1.0), y);
	COLOR = vec4(min(rgb * k * sqrt(k) * 1.6, vec3(1.0)), 1.0);
}
