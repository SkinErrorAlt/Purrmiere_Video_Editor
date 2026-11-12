shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform vec2 direction = vec2(1.0, 0.0);
uniform float size : hint_range(0.05, 1.0) = 0.35;

const int TAPS = 24;

void fragment() {
	vec2 st = direction / max(tex_size, vec2(1.0));
	float sigma = max(size * tex_size.y * 0.5, 0.5);
	float reach = sigma * 2.5;
	float stepw = max(reach / float(TAPS), 0.5);
	vec4 c = texture(TEXTURE, UV);
	vec3 sum = c.rgb * c.a;
	float wsum = c.a;
	float n = 1.0;
	for (int i = 1; i <= TAPS; i++) {
		float o = float(i) * stepw;
		if (o > reach) {
			break;
		}
		float g = exp(-0.5 * o * o / (sigma * sigma));
		vec4 a = texture(TEXTURE, UV + st * o);
		vec4 b = texture(TEXTURE, UV - st * o);
		sum += (a.rgb * a.a + b.rgb * b.a) * g;
		wsum += (a.a + b.a) * g;
		n += 2.0 * g;
	}
	COLOR = vec4(wsum > 0.00001 ? sum / wsum : vec3(0.5), wsum / n);
}
