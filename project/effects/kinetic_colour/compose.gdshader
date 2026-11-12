shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform int keep = 0;
uniform float boost : hint_range(0.0, 1.0) = 0.25;
uniform float grey_contrast : hint_range(0.0, 1.0) = 0.3;
uniform vec4 grey_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 now = texture(effect_tex, UV);
	vec3 rgb = now.a > 0.0001 ? now.rgb / now.a : vec3(0.0);
	float m = clamp(texture(TEXTURE, UV).r * 1.25, 0.0, 1.0);
	if (keep == 1) {
		m = 1.0 - m;
	}
	float l = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	float lc = mix(l, l * l * (3.0 - 2.0 * l), grey_contrast);
	vec3 grey = clamp(vec3(lc) * grey_tint.rgb, 0.0, 1.0);
	vec3 vivid = clamp(vec3(l) + (rgb - vec3(l)) * (1.0 + boost), 0.0, 1.0);
	vec3 out_c = mix(grey, vivid, m);
	COLOR = vec4(out_c * now.a, now.a);
}
