shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float amount : hint_range(-1.0, 1.0) = 0.5;
uniform vec4 haze_colour : source_color = vec4(0.85, 0.87, 0.9, 1.0);
uniform float sky_protect : hint_range(0.0, 1.0) = 0.5;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	rgb = clamp(rgb, 0.0, 1.0);
	float dark = clamp(texture(TEXTURE, UV).r, 0.0, 1.0);
	vec3 haze = clamp(haze_colour.rgb, vec3(0.05), vec3(1.0));
	vec3 result;
	if (amount >= 0.0) {
		float t = 1.0 - 0.95 * amount * dark;
		float near_haze = 1.0 - smoothstep(0.05, 0.3, length(rgb - haze));
		float sky = near_haze * smoothstep(0.35, 0.65, dot(rgb, LUMA));
		t = mix(t, 1.0, sky_protect * sky);
		result = (rgb - haze) / max(t, 0.1) + haze;
	} else {
		float thick = -amount * (0.25 + 0.6 * dark);
		result = mix(rgb, haze, thick);
	}
	COLOR = vec4(clamp(result, 0.0, 1.0) * a, a);
}
