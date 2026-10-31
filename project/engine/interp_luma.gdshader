shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D a_tex : filter_linear, repeat_disable;
uniform sampler2D b_tex : filter_linear, repeat_disable;
uniform sampler2D prev_tex : filter_nearest, repeat_disable;
uniform bool from_source = true;
uniform vec2 in_size = vec2(2.0);
uniform vec2 out_size = vec2(2.0);

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 p = floor(UV * out_size);
	vec2 acc = vec2(0.0);
	for (int j = 0; j < 2; j++) {
		for (int i = 0; i < 2; i++) {
			vec2 q = p * 2.0 + vec2(float(i), float(j));
			if (from_source) {
				vec2 uv = (q + 0.5) / in_size;
				acc += vec2(luma(texture(a_tex, uv).rgb), luma(texture(b_tex, uv).rgb));
			} else {
				ivec2 qi = ivec2(min(q, in_size - vec2(1.0)));
				acc += texelFetch(prev_tex, qi, 0).rg;
			}
		}
	}
	COLOR = vec4(acc * 0.25, 0.0, 1.0);
}
