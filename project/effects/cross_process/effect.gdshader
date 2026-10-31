shader_type canvas_item;
render_mode blend_disabled;

uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float contrast : hint_range(0.0, 1.0) = 0.5;
uniform vec4 tint_shadows : source_color = vec4(0.1, 0.45, 0.55, 1.0);
uniform vec4 tint_highlights : source_color = vec4(1.0, 0.92, 0.55, 1.0);

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float s_curve(float x, float k) {
	return mix(x, x * x * (3.0 - 2.0 * x), k);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	rgb = clamp(rgb, 0.0, 1.0);
	vec3 p = vec3(0.0);
	p.r = s_curve(rgb.r, 0.5 + contrast * 0.8);
	p.g = s_curve(rgb.g, 0.3 + contrast * 0.6);
	p.b = 0.2 + rgb.b * 0.65;
	p = clamp(p, 0.0, 1.0);
	float l = dot(p, LUMA);
	float w_low = 1.0 - smoothstep(0.0, 0.5, l);
	float w_high = smoothstep(0.5, 1.0, l);
	p.b -= 0.15 * w_high;
	p += (tint_shadows.rgb - vec3(dot(tint_shadows.rgb, LUMA))) * w_low * 0.25;
	p += (tint_highlights.rgb - vec3(dot(tint_highlights.rgb, LUMA))) * w_high * 0.25;
	float lp = dot(p, LUMA);
	p = vec3(lp) + (p - vec3(lp)) * 1.15;
	rgb = mix(rgb, p, amount);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
