shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float intensity : hint_range(0.0, 4.0) = 1.0;
uniform vec4 tint : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform bool stars_only = false;

void fragment() {
	vec4 o = texture(effect_tex, UV);
	vec4 r = texture(TEXTURE, UV);
	vec3 add = max(r.rgb, vec3(0.0)) * tint.rgb * max(intensity, 0.0);
	vec4 base = stars_only ? vec4(0.0) : o;
	float glow_a = clamp(max(add.r, max(add.g, add.b)), 0.0, 1.0);
	float oa = clamp(base.a + glow_a * (1.0 - base.a), 0.0, 1.0);
	vec3 rgb = min(base.rgb + add, vec3(oa));
	COLOR = vec4(max(rgb, vec3(0.0)), oa);
}
