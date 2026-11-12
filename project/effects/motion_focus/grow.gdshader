shader_type canvas_item;
render_mode blend_disabled;
uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(2.0);
uniform float px_scale = 1.0;
uniform float spread = 18.0;
uniform int stage = 0;

void fragment() {
	vec2 sz = vec2(textureSize(TEXTURE, 0));
	float full_w = float(textureSize(effect_tex, 0).x);
	float ps = max(px_scale * full_w / max(tex_size.x, 1.0), 0.0001);
	float texel_px = full_w / sz.x;
	ivec2 c = ivec2(floor(UV * sz));
	ivec2 hi = ivec2(sz) - 1;
	if (stage == 0) {
		float r = max(spread * ps / texel_px, 0.5);
		int ri = clamp(int(ceil(r)), 1, 10);
		float best = 0.0;
		for (int j = -10; j <= 10; j++) {
			for (int i = -10; i <= 10; i++) {
				if (abs(i) > ri || abs(j) > ri) {
					continue;
				}
				float d = length(vec2(float(i), float(j)));
				float k = clamp(1.0 - d / (r + 1.0), 0.0, 1.0);
				float m = texelFetch(TEXTURE, clamp(c + ivec2(i, j), ivec2(0), hi), 0).r;
				best = max(best, m * sqrt(k));
			}
		}
		COLOR = vec4(vec3(best), 1.0);
	} else {
		float acc = 0.0;
		float ws = 0.0;
		for (int j = -3; j <= 3; j++) {
			for (int i = -3; i <= 3; i++) {
				float w = exp(-float(i * i + j * j) / 4.5);
				acc += texelFetch(TEXTURE, clamp(c + ivec2(i, j), ivec2(0), hi), 0).r * w;
				ws += w;
			}
		}
		float m = acc / ws;
		COLOR = vec4(vec3(m), 1.0);
	}
}
