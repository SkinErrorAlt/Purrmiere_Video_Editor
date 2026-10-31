shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform float strength : hint_range(0.0, 1.0) = 0.1;
uniform int samples : hint_range(2, 32) = 12;
uniform float keep_centre : hint_range(0.0, 1.0) = 0.2;

void fragment() {
	int n = clamp(samples, 2, 32);
	vec2 d = UV - centre;
	float r = clamp(length(d) * 2.0, 0.0, 1.0);
	float amt = strength * smoothstep(keep_centre, 1.0, r);
	vec4 sum = vec4(0.0);
	for (int i = 0; i < n; i++) {
		float t = float(i) / float(n - 1);
		vec2 src = centre + d * (1.0 - amt * t);
		sum += texture(TEXTURE, clamp(src, vec2(0.0), vec2(1.0)));
	}
	COLOR = sum / float(n);
}
