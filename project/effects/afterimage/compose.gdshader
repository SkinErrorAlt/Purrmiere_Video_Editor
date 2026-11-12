shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float strength : hint_range(0.0, 4.0) = 2.6;
uniform float darken : hint_range(0.0, 1.0) = 0.35;
uniform float colour_shift : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec4 now = texture(effect_tex, UV);
	vec3 rgb = now.a > 0.0001 ? now.rgb / now.a : vec3(0.0);
	vec3 f = texture(TEXTURE, UV).rgb;
	float lf = dot(f, vec3(0.2126, 0.7152, 0.0722));
	vec3 complement = (vec3(lf) - f) * colour_shift;
	float light = 0.25 + 0.75 * smoothstep(0.0, 0.6, dot(rgb, vec3(0.2126, 0.7152, 0.0722)));
	vec3 d = (complement - vec3(lf) * darken) * strength * light;
	rgb = clamp(rgb + d, 0.0, 1.0);
	COLOR = vec4(rgb * now.a, now.a);
}
