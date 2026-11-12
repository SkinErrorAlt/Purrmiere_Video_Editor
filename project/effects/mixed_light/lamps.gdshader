shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float threshold : hint_range(0.0, 1.0) = 0.75;

float peak(vec4 c) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	return max(rgb.r, max(rgb.g, rgb.b)) * c.a;
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float aspect = size.y / size.x;
	float around = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398 + 0.3;
		vec2 d = vec2(cos(a) * aspect, sin(a));
		around += peak(texture(TEXTURE, UV + d * 0.06));
	}
	around /= 8.0;
	vec2 px = 0.5 / size;
	float mx = (peak(texture(TEXTURE, UV + vec2(-px.x, -px.y))) + peak(texture(TEXTURE, UV + vec2(px.x, -px.y))) + peak(texture(TEXTURE, UV + vec2(-px.x, px.y))) + peak(texture(TEXTURE, UV + vec2(px.x, px.y)))) * 0.25;
	float src = smoothstep(threshold, mix(threshold, 1.0, 0.5) + 0.02, mx) * mix(1.0, smoothstep(0.02, 0.25, mx - around), 0.7);
	COLOR = vec4(sqrt(clamp(src, 0.0, 1.0)), 0.0, 0.0, 1.0);
}
