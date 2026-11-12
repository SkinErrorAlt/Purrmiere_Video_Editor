shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never, shadows_disabled;


uniform vec4 tint : source_color = vec4(0.72, 0.86, 0.80, 1.0);
uniform float brightness : hint_range(0.0, 4.0) = 1.4;
uniform float fade : hint_range(0.0, 1.0) = 1.0;


void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d) * 2.0;
	float a = smoothstep(1.0, 0.0, r);
	a *= a;
	ALBEDO = tint.rgb * brightness;
	ALPHA = a * fade;
}
