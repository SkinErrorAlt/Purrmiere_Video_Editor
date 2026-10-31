shader_type canvas_item;
render_mode blend_disabled;

uniform int mode : hint_range(0, 1) = 0;
uniform float smoothness : hint_range(0.005, 0.3) = 0.04;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec3 w = vec3(0.2126, 0.7152, 0.0722);
	float l = dot(rgb, w);
	vec3 below = vec3(0.0);
	float total = 0.0;
	float k = 1.0 / max(smoothness, 0.001);
	for (int j = 0; j < 12; j++) {
		for (int i = 0; i < 12; i++) {
			vec4 t = texture(TEXTURE, (vec2(float(i), float(j)) + 0.5) / 12.0);
			if (t.a < 0.01) { continue; }
			vec3 s = t.rgb / t.a;
			if (mode == 0) {
				below += vec3(clamp((l - dot(s, w)) * k + 0.5, 0.0, 1.0));
			} else {
				below += clamp((rgb - s) * k + 0.5, 0.0, 1.0);
			}
			total += 1.0;
		}
	}
	vec3 o = rgb;
	if (total > 0.5) {
		vec3 cdf = below / total;
		o = mode == 0 ? rgb + (cdf.x - l) : cdf;
	}
	COLOR = vec4(clamp(o, 0.0, 1.0) * c.a, c.a);
}
