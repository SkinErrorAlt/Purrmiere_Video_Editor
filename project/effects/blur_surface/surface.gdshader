shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float radius : hint_range(0.0, 24.0) = 6.0;
uniform float threshold : hint_range(0.01, 1.0) = 0.18;
uniform vec2 direction = vec2(1.0, 0.0);

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

void fragment() {
	vec4 centre = texture(TEXTURE, UV);
	float sigma = max(radius * px_scale / 2.0, 0.001);
	int n = int(min(ceil(sigma * 2.5), 32.0));
	if (n < 1) {
		COLOR = centre;
	} else {
		vec2 px = direction / tex_size;
		float lc = dot(centre.rgb, LUMA);
		vec4 sum = centre;
		float wsum = 1.0;
		for (int i = -32; i <= 32; i++) {
			if (i == 0 || i < -n || i > n) {
				continue;
			}
			vec4 s = texture(TEXTURE, clamp(UV + px * float(i), vec2(0.0), vec2(1.0)));
			float x = float(i);
			float ws = exp(-0.5 * x * x / (sigma * sigma));
			float dl = abs(dot(s.rgb, LUMA) - lc) / threshold;
			float we = exp(-dl * dl);
			sum += s * ws * we;
			wsum += ws * we;
		}
		COLOR = sum / wsum;
	}
}
