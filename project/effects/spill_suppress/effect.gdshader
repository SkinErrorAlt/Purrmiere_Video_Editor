shader_type canvas_item;
render_mode blend_disabled;

uniform int screen : hint_range(0, 2) = 0;
uniform float strength : hint_range(0.0, 1.0) = 0.8;
uniform bool keep_luma = true;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 w = vec3(0.2126, 0.7152, 0.0722);
	float before = dot(rgb, w);
	if (screen == 0) {
		float cap = max(rgb.r, rgb.b);
		rgb.g = mix(rgb.g, min(rgb.g, cap), strength);
	} else if (screen == 1) {
		float cap = max(rgb.r, rgb.g);
		rgb.b = mix(rgb.b, min(rgb.b, cap), strength);
	} else {
		float cap = max(rgb.g, rgb.b);
		rgb.r = mix(rgb.r, min(rgb.r, cap), strength);
	}
	if (keep_luma) {
		float after = max(dot(rgb, w), 0.0001);
		rgb *= before / after;
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
