shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 4.0) = 1.2;
uniform bool ghosts_only = false;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec4 o = texture(effect_tex, UV);
	vec3 enc = texture(TEXTURE, UV).rgb;
	vec3 light = enc * enc * 4.0 * tint.rgb * tint.a * intensity;
	light += (hash12(FRAGCOORD.xy) - 0.5) / 255.0 * step(0.0005, max(light.r, max(light.g, light.b)));
	light = max(light, vec3(0.0));
	if (ghosts_only) {
		vec3 l = min(light, vec3(1.0));
		COLOR = vec4(l, max(l.r, max(l.g, l.b)));
	} else {
		COLOR = vec4(min(o.rgb + light * o.a, vec3(o.a)), o.a);
	}
}
