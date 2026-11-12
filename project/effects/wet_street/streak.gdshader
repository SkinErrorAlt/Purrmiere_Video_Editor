shader_type canvas_item;
render_mode blend_disabled;

uniform float horizon : hint_range(0.05, 0.95) = 0.62;
uniform float streak_length : hint_range(0.0, 1.0) = 0.45;
uniform float reach_scale = 1.0;

vec3 dec(vec4 c) {
	return c.rgb * c.rgb;
}

void fragment() {
	float span = mix(0.03, 0.6, clamp(streak_length, 0.0, 1.0)) * reach_scale;
	vec3 sum = vec3(0.0);
	float wsum = 0.0;
	for (int i = 0; i < 28; i++) {
		float k = (float(i) + 0.5) / 28.0;
		float d = mix(-0.22, 1.0, k) * span;
		float w = d < 0.0 ? exp(d / max(span * 0.06, 0.0005)) : exp(-d / max(span * 0.38, 0.0005));
		vec2 uv = vec2(UV.x, UV.y + d);
		float inside = step(uv.y, horizon);
		sum += dec(texture(TEXTURE, uv)) * w * inside;
		wsum += w;
	}
	COLOR = vec4(sqrt(clamp(sum / max(wsum, 0.0001) * 2.2, 0.0, 1.0)), 1.0);
}
