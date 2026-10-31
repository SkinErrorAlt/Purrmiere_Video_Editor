shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform int shape : hint_range(0, 1) = 0;
uniform vec2 start = vec2(0.5, 0.55);
uniform vec2 end = vec2(0.5, 0.98);
uniform float start_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float end_opacity : hint_range(0.0, 1.0) = 0.0;
uniform int curve : hint_range(0, 3) = 0;
uniform bool dither = true;

float shaped(float t) {
	float x = clamp(t, 0.0, 1.0);
	if (curve == 0) {
		return x * x * (3.0 - 2.0 * x);
	}
	if (curve == 2) {
		return x * x;
	}
	if (curve == 3) {
		return 1.0 - (1.0 - x) * (1.0 - x);
	}
	return x;
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	vec2 p = UV * size;
	vec2 s = start * size;
	vec2 e = end * size;
	vec2 d = e - s;
	float len2 = max(dot(d, d), 1.0);
	float t = 0.0;
	if (shape == 0) {
		t = dot(p - s, d) / len2;
	} else {
		t = length(p - s) / sqrt(len2);
	}
	float m = mix(start_opacity, end_opacity, shaped(t));
	if (dither) {
		float n = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		m += (n - 0.5) / 255.0;
	}
	m = clamp(m, 0.0, 1.0);
	vec4 c = texture(TEXTURE, UV);
	COLOR = c * m;
}
