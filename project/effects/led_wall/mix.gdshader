shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D led_tex : filter_linear, repeat_disable;
uniform float bloom : hint_range(0.0, 2.0) = 0.45;

void fragment() {
	vec4 led = texture(led_tex, UV);
	vec4 g = texture(TEXTURE, UV);
	vec3 glow = g.rgb * bloom * 0.3;
	vec3 rgb = led.rgb + glow * (1.0 - led.rgb * 0.5);
	COLOR = vec4(min(rgb, vec3(led.a)), led.a);
}
