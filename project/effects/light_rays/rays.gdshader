shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.25);
uniform float ray_length : hint_range(0.0, 1.0) = 0.5;
uniform float span = 1.0;

void fragment() {
	vec2 d = UV - centre;
	float reach = clamp(ray_length, 0.0, 1.0) * span;
	vec4 sum = vec4(0.0);
	float wsum = 0.0;
	for (int i = 0; i < 12; i++) {
		float t = float(i) / 11.0;
		float s = 1.0 - reach * t;
		vec2 uv = centre + d * s;
		float w = 1.0 - 0.5 * t;
		sum += texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0))) * w;
		wsum += w;
	}
	COLOR = sum / wsum;
}
