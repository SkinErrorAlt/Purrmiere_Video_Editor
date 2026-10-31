shader_type canvas_item;
render_mode blend_disabled;

uniform int take_r : hint_range(0, 6) = 0;
uniform int take_g : hint_range(0, 6) = 1;
uniform int take_b : hint_range(0, 6) = 2;
uniform int take_a : hint_range(0, 6) = 3;

float pick(int which, vec3 rgb, float a, float luma) {
	if (which == 0) { return rgb.r; }
	if (which == 1) { return rgb.g; }
	if (which == 2) { return rgb.b; }
	if (which == 3) { return a; }
	if (which == 4) { return luma; }
	if (which == 5) { return 1.0; }
	return 0.0;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 o = vec3(pick(take_r, rgb, a, luma), pick(take_g, rgb, a, luma), pick(take_b, rgb, a, luma));
	float oa = clamp(pick(take_a, rgb, a, luma), 0.0, 1.0);
	COLOR = vec4(clamp(o, 0.0, 1.0) * oa, oa);
}
