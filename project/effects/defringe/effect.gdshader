shader_type canvas_item;
render_mode blend_disabled;

uniform int fringe : hint_range(0, 2) = 0;
uniform vec4 matte_colour : source_color = vec4(0.1, 0.7, 0.25, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 m = vec3(0.0);
	if (fringe == 1) {
		m = vec3(1.0);
	} else if (fringe == 2) {
		m = matte_colour.rgb;
	}
	vec3 fixed_rgb = clamp((rgb - m * (1.0 - a)) / max(a, 0.02), 0.0, 1.0);
	float w = strength * smoothstep(0.0, 0.08, a);
	vec3 o = mix(rgb, fixed_rgb, clamp(w, 0.0, 1.0));
	COLOR = vec4(o * a, a);
}
