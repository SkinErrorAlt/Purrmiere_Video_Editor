shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform int mode = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform bool colour = true;

vec3 gain_at(sampler2D tex, vec2 uv) {
	return (texture(tex, uv).rgb - 0.5) * 4.0;
}

void fragment() {
	vec4 now = texture(effect_tex, UV);
	vec3 g = vec3(0.0);
	if (mode == 0) {
		vec3 all_g[48];
		int k = 0;
		vec3 mean_g = vec3(0.0);
		for (int j = 0; j < 6; j++) {
			for (int i = 0; i < 8; i++) {
				vec3 v = gain_at(TEXTURE, (vec2(float(i), float(j)) + 0.5) / vec2(8.0, 6.0));
				all_g[k] = v;
				mean_g += v;
				k++;
			}
		}
		mean_g /= 48.0;
		vec3 acc = vec3(0.0);
		float wsum = 0.0;
		for (int i = 0; i < 48; i++) {
			float d = length(all_g[i] - mean_g);
			float w = exp(-d * d / 0.02);
			acc += all_g[i] * w;
			wsum += w;
		}
		g = wsum > 0.0001 ? acc / wsum : mean_g;
	} else {
		vec2 px = SCREEN_PIXEL_SIZE * 24.0;
		float wsum = 0.0;
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				float w = (i == 0 && j == 0) ? 2.0 : 1.0;
				g += gain_at(TEXTURE, UV + vec2(float(i), float(j)) * px) * w;
				wsum += w;
			}
		}
		g /= wsum;
	}
	if (!colour) {
		g = vec3(dot(g, vec3(0.2126, 0.7152, 0.0722)));
	}
	g = clamp(g * strength, vec3(-1.5), vec3(1.5));
	vec3 rgb = now.a > 0.0001 ? now.rgb / now.a : vec3(0.0);
	vec3 l = rgb * rgb * exp2(g);
	rgb = clamp(sqrt(l), 0.0, 1.0);
	COLOR = vec4(rgb * now.a, now.a);
}
