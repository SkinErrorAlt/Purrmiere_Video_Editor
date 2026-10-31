shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float glow_size : hint_range(-24.0, 24.0) = 5.0;
uniform float glow_brightness : hint_range(0.0, 50.0) = 15.0;
uniform vec4 glow_colour : source_color = vec4(0.2, 0.55, 1.0, 1.0);
uniform vec4 dark_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 light_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 o = texture(effect_tex, UV);
	float a = o.a;
	vec3 rgb = a > 0.0001 ? clamp(o.rgb / a, 0.0, 1.0) : vec3(0.0);
	float l = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	vec4 bl = texture(TEXTURE, UV);
	float b = bl.g > 0.0001 ? clamp(bl.r / bl.g, 0.0, 1.0) : 0.0;
	bool inverted = glow_size < 0.0;
	float t = inverted ? 1.0 - l : l;
	float bt = inverted ? 1.0 - b : b;
	float halo = max(bt - t, 0.0);
	float k = glow_brightness / 15.0;
	float body = smoothstep(0.15, 1.0, bt);
	float g = clamp((body * 1.05 + halo * 5.0) * k, 0.0, 1.3);
	vec3 base = mix(dark_colour.rgb, light_colour.rgb, t * t * 0.4);
	vec3 col = 1.0 - (1.0 - base) * (1.0 - clamp(glow_colour.rgb * g, 0.0, 1.0));
	col += glow_colour.rgb * max(g - 1.0, 0.0);
	float core = smoothstep(0.72, 0.98, t) * smoothstep(0.0, 0.6, k);
	col = mix(col, mix(glow_colour.rgb, light_colour.rgb, 0.75), core * 0.85);
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}
