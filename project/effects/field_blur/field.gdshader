shader_type canvas_item;
render_mode blend_disabled;

uniform int pins : hint_range(1, 4) = 2;
uniform vec2 pin_a = vec2(0.3, 0.35);
uniform float blur_a : hint_range(0.0, 120.0) = 0.0;
uniform vec2 pin_b = vec2(0.75, 0.75);
uniform float blur_b : hint_range(0.0, 120.0) = 40.0;
uniform vec2 pin_c = vec2(0.8, 0.2);
uniform float blur_c : hint_range(0.0, 120.0) = 20.0;
uniform vec2 pin_d = vec2(0.2, 0.85);
uniform float blur_d : hint_range(0.0, 120.0) = 20.0;
uniform float light_bokeh : hint_range(0.0, 100.0) = 0.0;
uniform vec2 direction = vec2(1.0, 0.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float blur_here(vec2 uv) {
	vec2 sz = max(tex_size, vec2(1.0));
	vec2 asp = vec2(sz.x / sz.y, 1.0);
	vec2 ps[4] = vec2[4](pin_a, pin_b, pin_c, pin_d);
	float bs[4] = float[4](blur_a, blur_b, blur_c, blur_d);
	float wsum = 0.0;
	float acc = 0.0;
	int n = clamp(pins, 1, 4);
	for (int i = 0; i < 4; i++) {
		if (i >= n) {
			break;
		}
		float d = length((uv - ps[i]) * asp);
		float w = 1.0 / max(d * d, 0.00001);
		wsum += w;
		acc += w * bs[i];
	}
	return acc / max(wsum, 0.00001);
}

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	float r = blur_here(UV) * max(px_scale, 0.0001);
	if (r < 0.3) {
		COLOR = texture(TEXTURE, UV);
	} else {
		float sigma = max(r * 0.5, 0.3);
		int taps = 24;
		float stride = max(r / float(taps), 0.5);
		vec2 dir = direction / sz;
		vec4 acc = vec4(0.0);
		float wsum = 0.0;
		float boost = light_bokeh / 100.0 * 6.0;
		bool second = direction.y > 0.5;
		for (int i = -24; i <= 24; i++) {
			float x = float(i) * stride;
			if (abs(x) > r * 1.5) {
				continue;
			}
			vec4 c = texture(TEXTURE, clamp(UV + dir * x, vec2(0.0), vec2(1.0)));
			float w = exp(-0.5 * x * x / (sigma * sigma));
			if (boost > 0.0 && !second) {
				float l = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
				w *= 1.0 + boost * pow(clamp(l, 0.0, 1.0), 6.0);
			}
			acc += c * w;
			wsum += w;
		}
		COLOR = acc / max(wsum, 0.00001);
	}
}
