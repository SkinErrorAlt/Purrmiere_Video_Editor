shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float intensity : hint_range(0.0, 4.0) = 1.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool glow_only = false;

void fragment() {
	vec4 orig = texture(effect_tex, UV);
	vec4 g = texture(TEXTURE, UV) * intensity * 0.25;
	vec3 glow = g.rgb * tint.rgb;
	if (glow_only) {
		COLOR = vec4(glow, max(g.a, orig.a));
	} else {
		COLOR = vec4(orig.rgb + glow, clamp(orig.a + g.a, 0.0, 1.0));
	}
}
