shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float protect : hint_range(0.0, 1.0) = 0.6;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
const float SPAN = 4.0;

vec3 to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	vec3 sum = vec3(0.0);
	float wsum = 0.0;
	float sigma = mix(2.5, 0.45, clamp(protect, 0.0, 1.0));
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 4; i++) {
			vec4 s = texture(TEXTURE, UV + px * (vec2(float(i), float(j)) - 1.5));
			vec3 rgb = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
			vec3 lin = to_linear(rgb);
			float y = dot(lin, LUMA);
			float hi = max(rgb.r, max(rgb.g, rgb.b));
			vec3 c = clamp(log2(max(lin, vec3(0.00002)) / max(y, 0.00002)), -2.0, 2.0);
			float sat = length(c);
			float w = smoothstep(0.004, 0.02, y) * (1.0 - smoothstep(0.94, 0.99, hi)) * exp(-(sat * sat) / (sigma * sigma)) * step(0.5, s.a);
			sum += c * w;
			wsum += w;
		}
	}
	vec3 m = wsum > 0.00001 ? sum / wsum : vec3(0.0);
	COLOR = vec4(clamp(m / SPAN + 0.5, 0.0, 1.0), wsum / 16.0);
}
