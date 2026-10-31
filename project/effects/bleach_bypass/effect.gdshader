shader_type canvas_item;
render_mode blend_disabled;

uniform float strength : hint_range(0.0, 1.0) = 0.7;
uniform float contrast : hint_range(0.5, 3.0) = 1.3;
uniform float keep_colour : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 grey = vec3(luma);
	vec3 desat = mix(grey, rgb, keep_colour);
	vec3 overlay = mix(2.0 * desat * grey, 1.0 - 2.0 * (1.0 - desat) * (1.0 - grey), step(0.5, grey));
	vec3 mixed = mix(desat, overlay, strength);
	rgb = (mixed - 0.5) * contrast + 0.5;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
