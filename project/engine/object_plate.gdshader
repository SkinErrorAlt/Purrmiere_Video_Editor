shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 matte_size = vec2(128.0, 128.0);
uniform float edge_contrast : hint_range(1.0, 24.0) = 1.0;
uniform float edge_shift : hint_range(-0.5, 0.5) = 0.0;

float cubic_weight(float x) {
	float a = abs(x);
	if (a < 1.0) {
		return (1.5 * a - 2.5) * a * a + 1.0;
	}
	if (a < 2.0) {
		return ((-0.5 * a + 2.5) * a - 4.0) * a + 2.0;
	}
	return 0.0;
}

float smooth_matte(sampler2D matte, vec2 uv) {
	vec2 px = uv * matte_size - 0.5;
	vec2 base = floor(px);
	vec2 frac = px - base;
	float sum = 0.0;
	float total = 0.0;
	for (int j = -1; j <= 2; j++) {
		float wy = cubic_weight(float(j) - frac.y);
		for (int i = -1; i <= 2; i++) {
			float wx = cubic_weight(float(i) - frac.x);
			vec2 at = (base + vec2(float(i), float(j)) + 0.5) / matte_size;
			float w = wx * wy;
			sum += texture(matte, clamp(at, vec2(0.0), vec2(1.0))).r * w;
			total += w;
		}
	}
	return sum / max(total, 0.0001);
}

void fragment() {
	vec2 inside = (UV - region.xy) / max(region.zw, vec2(0.0001));
	float on = step(0.0, inside.x) * step(inside.x, 1.0) * step(0.0, inside.y) * step(inside.y, 1.0);
	float a = smooth_matte(TEXTURE, clamp(inside, vec2(0.0), vec2(1.0)));
	a = clamp((a - 0.5 + edge_shift) * edge_contrast + 0.5, 0.0, 1.0);
	COLOR = vec4(vec3(1.0), a * on);
}
