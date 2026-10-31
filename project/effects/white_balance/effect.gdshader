shader_type canvas_item;
render_mode blend_disabled;

uniform float temperature : hint_range(-1.0, 1.0) = 0.0;
uniform float green_tint : hint_range(-1.0, 1.0) = 0.0;
uniform bool keep_luma = true;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 w = vec3(0.2126, 0.7152, 0.0722);
	float before = dot(rgb, w);
	rgb.r *= 1.0 + temperature * 0.5;
	rgb.b *= 1.0 - temperature * 0.5;
	rgb.g *= 1.0 + green_tint * 0.5;
	rgb.r *= 1.0 - green_tint * 0.15;
	rgb.b *= 1.0 - green_tint * 0.15;
	if (keep_luma) {
		float after = max(dot(rgb, w), 0.0001);
		rgb *= before / after;
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
