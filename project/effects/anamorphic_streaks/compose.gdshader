shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float intensity : hint_range(0.0, 4.0) = 1.0;
uniform vec4 colour : source_color = vec4(0.35, 0.55, 1.0, 1.0);

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec4 o = texture(effect_tex, UV);
	vec4 s = texture(TEXTURE, UV);
	float l = max(dot(s.rgb, LUMA), 0.0);
	float e = l * intensity * 4.0;
	float lit = 1.0 - exp(-e);
	vec3 add = colour.rgb * colour.a * lit * 1.4;
	float glow_a = clamp(max(add.r, max(add.g, add.b)), 0.0, 1.0);
	float oa = clamp(o.a + glow_a * (1.0 - o.a), 0.0, 1.0);
	vec3 rgb = min(o.rgb + add, vec3(oa));
	COLOR = vec4(max(rgb, vec3(0.0)), oa);
}
