shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float amount : hint_range(0.0, 2.0) = 0.6;
uniform float radius : hint_range(0.0, 1.5) = 0.75;
uniform float softness : hint_range(0.0, 1.0) = 0.45;
uniform float roundness : hint_range(0.0, 1.0) = 1.0;
uniform vec4 colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 centre = vec2(0.5, 0.5);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec2 d = (UV - centre) * 2.0;
	float aspect = tex_size.x / max(tex_size.y, 1.0);
	d.x *= mix(1.0, aspect, roundness);
	float r = length(d) * 0.70710678;
	float v = smoothstep(radius, radius + max(softness, 0.001), r);
	rgb = mix(rgb, colour.rgb, v * amount * colour.a);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * c.a, c.a);
}
