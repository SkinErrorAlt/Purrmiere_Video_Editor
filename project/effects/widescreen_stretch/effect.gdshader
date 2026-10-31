shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float stretched_by : hint_range(0.75, 1.6) = 1.333;
uniform float hold : hint_range(0.0, 1.0) = 0.6;
uniform float middle : hint_range(0.25, 0.75) = 0.5;
uniform bool show_guides = false;

float power_for(float s) {
	float n_max = 8.0;
	if (s > 1.0001) {
		n_max = clamp((s - 0.3) / (s - 1.0), 1.0, 8.0);
	}
	return mix(1.0, n_max, clamp(hold, 0.0, 1.0));
}

float shape(float t, float s, float n) {
	return s * t + (1.0 - s) * pow(t, n);
}

float slope(float t, float s, float n) {
	return s + n * (1.0 - s) * pow(t, max(n - 1.0, 0.0));
}

void fragment() {
	float s = clamp(stretched_by, 0.75, 1.6);
	float n = power_for(s);
	float m = clamp(middle, 0.25, 0.75);
	float x = UV.x;
	float x_in = x;
	float t = 0.0;
	if (x < m) {
		t = clamp((m - x) / m, 0.0, 1.0);
		x_in = m - shape(t, s, n) * m;
	} else {
		t = clamp((x - m) / (1.0 - m), 0.0, 1.0);
		x_in = m + shape(t, s, n) * (1.0 - m);
	}
	vec4 c = texture(TEXTURE, vec2(clamp(x_in, 0.0, 1.0), UV.y));
	if (show_guides) {
		float local = slope(t, s, n);
		float natural = 1.0 - smoothstep(0.04, 0.08, abs(local - s) / s);
		vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
		rgb = mix(rgb, vec3(0.2, 0.9, 0.4), natural * 0.35);
		COLOR = vec4(rgb * c.a, c.a);
	} else {
		COLOR = c;
	}
}
