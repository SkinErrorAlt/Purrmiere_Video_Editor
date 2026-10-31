shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.4);
uniform float radius : hint_range(0.01, 2.0) = 0.35;
uniform float softness : hint_range(0.0, 1.0) = 0.5;
uniform float brightness : hint_range(0.0, 4.0) = 1.3;
uniform float outside : hint_range(0.0, 1.0) = 0.25;
uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 tex_size;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 aspect = vec2(max(tex_size.x, 1.0) / max(tex_size.y, 1.0), 1.0);
	float r = length((UV - centre) * aspect);
	float inner = max(radius * (1.0 - softness), 0.0);
	float cone = 1.0 - smoothstep(inner, max(radius, inner + 0.0001), r);
	float lit = mix(outside, brightness, cone);
	rgb *= mix(vec3(1.0), colour.rgb, cone) * lit;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
