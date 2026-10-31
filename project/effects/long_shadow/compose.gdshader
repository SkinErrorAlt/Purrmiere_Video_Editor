shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec4 colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec4 o = texture(effect_tex, UV);
	float s = clamp(texture(TEXTURE, UV).a, 0.0, 1.0);
	float sa = clamp(s * opacity * colour.a, 0.0, 1.0);
	vec4 sh = vec4(colour.rgb * sa, sa);
	COLOR = o + sh * (1.0 - o.a);
}
