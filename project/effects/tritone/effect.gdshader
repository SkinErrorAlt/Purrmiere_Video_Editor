shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 highlights : source_color = vec4(1.0, 0.97, 0.88, 1.0);
uniform vec4 midtones : source_color = vec4(0.6, 0.45, 0.3, 1.0);
uniform vec4 shadows : source_color = vec4(0.06, 0.04, 0.08, 1.0);
uniform float balance : hint_range(0.1, 0.9) = 0.5;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	float l = clamp(dot(rgb, LUMA), 0.0, 1.0);
	float b = clamp(balance, 0.1, 0.9);
	vec3 outc;
	if (l < b) {
		outc = mix(shadows.rgb, midtones.rgb, l / b);
	} else {
		outc = mix(midtones.rgb, highlights.rgb, (l - b) / (1.0 - b));
	}
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
