shader_type canvas_item;
render_mode blend_disabled;

const int MAX_KEYS = 33;
const int MAX_TAPS = 512;

uniform sampler2D layer_tex : filter_linear, repeat_disable;
uniform vec2 rect_origin = vec2(0.0, 0.0);
uniform vec2 rect_size = vec2(1.0, 1.0);
uniform int keys = 2;
uniform int taps = 1;
uniform vec4 gm[33];
uniform vec2 go[33];

float interleaved_noise(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	vec2 p = rect_origin + UV * rect_size;
	int n = clamp(taps, 1, MAX_TAPS);
	int k = clamp(keys, 2, MAX_KEYS);
	float jitter = n > 1 ? interleaved_noise(floor(p)) : 0.5;
	vec4 acc = vec4(0.0);
	for (int i = 0; i < MAX_TAPS; i++) {
		if (i >= n) {
			break;
		}
		float s = (float(i) + jitter) / float(n);
		float f = s * float(k - 1);
		int a = min(int(floor(f)), k - 2);
		float w = f - float(a);
		vec4 m = mix(gm[a], gm[a + 1], w);
		vec2 o = mix(go[a], go[a + 1], w);
		vec2 uv = vec2(m.x * p.x + m.z * p.y + o.x, m.y * p.x + m.w * p.y + o.y);
		if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
			acc += texture(layer_tex, uv);
		}
	}
	COLOR = acc / float(n);
}
