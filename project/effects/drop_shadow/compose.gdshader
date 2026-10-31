shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform bool shadow_only = false;

void fragment() {
	vec4 shadow = texture(TEXTURE, UV);
	vec4 orig = texture(effect_tex, UV);
	if (shadow_only) {
		COLOR = shadow;
	} else {
		COLOR = orig + shadow * (1.0 - orig.a);
	}
}
