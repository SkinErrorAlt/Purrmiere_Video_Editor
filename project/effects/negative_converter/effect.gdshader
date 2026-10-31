shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 base : source_color = vec4(0.86, 0.55, 0.36, 1.0);
uniform float density_range : hint_range(0.2, 3.0) = 1.1;
uniform float exposure : hint_range(-3.0, 3.0) = 0.0;
uniform float contrast : hint_range(0.2, 3.0) = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec3 t = clamp(rgb / max(base.rgb, vec3(0.01)), vec3(0.0005), vec3(1.0));
	vec3 dens = -log(t) / 2.302585;
	vec3 pos = clamp(dens / max(density_range, 0.01) * exp2(exposure), 0.0, 1.0);
	vec3 o = pow(pos, vec3(1.0 / max(contrast, 0.01)));
	COLOR = vec4(clamp(o, 0.0, 1.0) * c.a, c.a);
}
