shader_type canvas_item;
render_mode blend_disabled;

uniform int source = 0;
uniform float smoothness : hint_range(0.0, 60.0) = 6.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float signal(vec4 c) {
	float a = max(c.a, 0.0001);
	vec3 s = clamp(c.rgb / a, 0.0, 1.0);
	float v = dot(s, vec3(0.2126, 0.7152, 0.0722));
	if (source == 1) {
		v = 1.0 - v;
	} else if (source == 2) {
		v = s.r;
	} else if (source == 3) {
		v = s.g;
	} else if (source == 4) {
		v = s.b;
	} else if (source == 5) {
		float mx = max(s.r, max(s.g, s.b));
		float mn = min(s.r, min(s.g, s.b));
		v = mx > 0.0001 ? (mx - mn) / mx : 0.0;
	} else if (source == 6) {
		v = 1.0;
	}
	return v * c.a;
}

void fragment() {
	float sigma = max(smoothness * max(px_scale, 0.0001), 0.35);
	float reach = sigma * 2.5;
	int n = int(clamp(ceil(reach), 1.0, 20.0));
	float stp = max(reach / float(n), 1.0);
	float px = 1.0 / max(tex_size.x, 1.0);
	float sum = 0.0;
	float wsum = 0.0;
	for (int i = -n; i <= n; i++) {
		float o = float(i) * stp;
		float w = exp(-0.5 * o * o / (sigma * sigma));
		sum += signal(texture(TEXTURE, UV + vec2(o * px, 0.0))) * w;
		wsum += w;
	}
	float v = clamp(sum / max(wsum, 0.0001), 0.0, 1.0);
	float hi = floor(v * 255.0) / 255.0;
	COLOR = vec4(hi, fract(v * 255.0), 0.0, 1.0);
}
