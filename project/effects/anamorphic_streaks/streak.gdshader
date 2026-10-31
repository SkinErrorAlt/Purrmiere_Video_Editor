shader_type canvas_item;
render_mode blend_disabled;

uniform float streak_length : hint_range(0.0, 1.0) = 0.5;
uniform float span = 1.0;
uniform bool vertical = false;

void fragment() {
	vec2 dir = vertical ? vec2(0.0, 1.0) : vec2(1.0, 0.0);
	float reach = max(streak_length, 0.01) * span;
	vec4 sum = texture(TEXTURE, UV);
	float wsum = 1.0;
	for (int k = 1; k <= 8; k++) {
		float t = float(k) / 8.0;
		float w = exp(-3.0 * t);
		vec2 off = dir * reach * t;
		vec2 up = UV + off;
		vec2 dn = UV - off;
		if (up.x <= 1.0 && up.y <= 1.0) {
			sum += texture(TEXTURE, up) * w;
		}
		if (dn.x >= 0.0 && dn.y >= 0.0) {
			sum += texture(TEXTURE, dn) * w;
		}
		wsum += 2.0 * w;
	}
	COLOR = sum / wsum;
}
