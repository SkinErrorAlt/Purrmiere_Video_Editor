shader_type canvas_item;
render_mode blend_disabled;

uniform float size : hint_range(0.0, 20.0) = 4.0;
uniform float tolerance : hint_range(0.01, 1.0) = 0.15;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float r = max(size, 0.0) * max(px_scale, 0.0001);
	vec4 centre_c = texture(TEXTURE, UV);
	if (r < 0.01) {
		COLOR = centre_c;
	} else {
		vec4 s[25];
		vec2 stride = vec2(r * 0.5) / dims;
		for (int j = 0; j < 5; j++) {
			for (int i = 0; i < 5; i++) {
				s[j * 5 + i] = texture(TEXTURE, clamp(UV + vec2(float(i - 2), float(j - 2)) * stride, vec2(0.0), vec2(1.0)));
			}
		}
		float tol = max(tolerance, 0.001);
		float inv = 1.0 / (tol * tol);
		float best_score = -1.0;
		int best = 12;
		for (int i = 0; i < 25; i++) {
			float score = (i == 12) ? 0.5 : 0.0;
			for (int j = 0; j < 25; j++) {
				vec4 dv = s[i] - s[j];
				score += max(1.0 - dot(dv, dv) * inv, 0.0);
			}
			if (score > best_score) {
				best_score = score;
				best = i;
			}
		}
		vec4 ref = s[best];
		vec4 acc = vec4(0.0);
		float wsum = 0.0;
		for (int j = 0; j < 25; j++) {
			vec4 dv = s[j] - ref;
			float w = max(1.0 - dot(dv, dv) * inv, 0.0);
			acc += s[j] * w;
			wsum += w;
		}
		COLOR = wsum > 0.0 ? acc / wsum : centre_c;
	}
}
