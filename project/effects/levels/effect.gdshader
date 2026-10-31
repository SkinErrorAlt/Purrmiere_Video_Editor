shader_type canvas_item;
render_mode blend_disabled;

uniform float in_black : hint_range(0.0, 1.0) = 0.0;
uniform float in_white : hint_range(0.0, 1.0) = 1.0;
uniform float gamma : hint_range(0.1, 4.0) = 1.0;
uniform float out_black : hint_range(0.0, 1.0) = 0.0;
uniform float out_white : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	rgb = clamp((rgb - in_black) / max(in_white - in_black, 0.001), 0.0, 1.0);
	rgb = pow(rgb, vec3(1.0 / gamma));
	rgb = out_black + rgb * (out_white - out_black);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * c.a, c.a);
}
