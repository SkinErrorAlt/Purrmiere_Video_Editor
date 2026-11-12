shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform bool across = false;
uniform float size : hint_range(8.0, 600.0) = 90.0;
uniform float streak : hint_range(1.0, 8.0) = 1.0;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;

const int TAPS = 40;

vec3 to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_display(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

void fragment() {
	float a = radians(angle);
	vec2 dir = across ? vec2(-sin(a), cos(a)) : vec2(cos(a), sin(a));
	float sigma = max(size * px_scale * (across ? 1.0 : max(streak, 1.0)) * 0.5, 0.5);
	vec2 st = dir / max(tex_size, vec2(1.0));
	float reach = sigma * 2.6;
	float stepw = max(reach / float(TAPS), 0.5);
	vec3 sum = to_linear(texture(TEXTURE, UV).rgb);
	float wsum = 1.0;
	for (int i = 1; i <= TAPS; i++) {
		float o = float(i) * stepw;
		if (o > reach) {
			break;
		}
		float w = exp(-0.5 * o * o / (sigma * sigma));
		sum += (to_linear(texture(TEXTURE, UV + st * o).rgb) + to_linear(texture(TEXTURE, UV - st * o).rgb)) * w;
		wsum += 2.0 * w;
	}
	COLOR = vec4(to_display(sum / wsum), 1.0);
}
