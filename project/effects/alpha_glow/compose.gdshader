shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float intensity : hint_range(0.0, 4.0) = 1.5;
uniform vec4 start_colour : source_color = vec4(1.0, 0.9, 0.45, 1.0);
uniform vec4 end_colour : source_color = vec4(1.0, 0.3, 0.1, 1.0);
uniform bool behind = true;

void fragment() {
	vec4 o = texture(effect_tex, UV);
	float g = clamp(texture(TEXTURE, UV).a, 0.0, 1.0);
	float outer = clamp(g * 2.0, 0.0, 1.0);
	vec4 col_out = mix(end_colour, start_colour, outer);
	float ga = clamp(sqrt(outer) * intensity * 0.8, 0.0, 1.0) * col_out.a;
	vec4 under = vec4(col_out.rgb * ga, ga);
	vec4 base = o;
	if (!behind) {
		float inner = clamp((1.0 - g) * 2.0, 0.0, 1.0);
		vec4 col_in = mix(end_colour, start_colour, inner);
		float gi = clamp(inner * intensity, 0.0, 1.0) * col_in.a;
		base.rgb = min(o.rgb + col_in.rgb * gi * o.a, vec3(o.a));
	}
	COLOR = base + under * (1.0 - base.a);
}
