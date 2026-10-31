shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 shadow_colour : source_color = vec4(0.15, 0.35, 0.45, 1.0);
uniform vec4 highlight_colour : source_color = vec4(1.0, 0.72, 0.45, 1.0);
uniform float balance : hint_range(0.0, 1.0) = 0.5;
uniform float strength : hint_range(0.0, 1.0) = 0.35;
uniform bool keep_luma = true;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 w = vec3(0.2126, 0.7152, 0.0722);
	float before = dot(rgb, w);
	float t = smoothstep(0.0, 1.0, clamp((before - balance) * 2.0 + 0.5, 0.0, 1.0));
	vec3 tintc = mix(shadow_colour.rgb, highlight_colour.rgb, t);
	rgb = mix(rgb, rgb * tintc * 2.0, strength);
	if (keep_luma) {
		float after = max(dot(rgb, w), 0.0001);
		rgb *= before / after;
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
