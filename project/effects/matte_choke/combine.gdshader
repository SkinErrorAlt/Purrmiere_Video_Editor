shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D matte_tex : filter_linear, repeat_disable;
uniform bool edge_colour_fix = true;
uniform bool show_matte = false;

void fragment() {
	float na = clamp(texture(matte_tex, UV).a, 0.0, 1.0);
	vec4 orig = texture(effect_tex, UV);
	float oa = orig.a;
	vec3 own = oa > 0.0001 ? clamp(orig.rgb / oa, 0.0, 1.0) : vec3(0.0);
	vec3 rgb = own;
	if (edge_colour_fix) {
		vec4 fill = texture(TEXTURE, UV);
		if (fill.a > 0.001) {
			rgb = mix(clamp(fill.rgb, 0.0, 1.0), own, smoothstep(0.9, 1.0, oa));
		}
	}
	if (show_matte) {
		COLOR = vec4(vec3(na), 1.0);
	} else {
		COLOR = vec4(clamp(rgb, 0.0, 1.0) * na, na);
	}
}
