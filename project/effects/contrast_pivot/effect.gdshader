shader_type canvas_item;
render_mode blend_disabled;

uniform float contrast : hint_range(0.0, 3.0) = 1.2;
uniform float pivot : hint_range(0.05, 0.95) = 0.43;
uniform float soft_low : hint_range(0.0, 1.0) = 0.25;
uniform float soft_high : hint_range(0.0, 1.0) = 0.35;
uniform int apply_to : hint_range(0, 1) = 0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float shape(float x) {
	float y = pivot + (x - pivot) * contrast;
	float kh = soft_high * 0.35;
	float kl = soft_low * 0.25;
	if (kh > 0.0001 && y > 1.0 - kh) {
		y = 1.0 - kh + kh * tanh((y - (1.0 - kh)) / kh);
	}
	if (kl > 0.0001 && y < kl) {
		y = kl - kl * tanh((kl - y) / kl);
	}
	return clamp(y, 0.0, 1.0);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 outc;
	if (apply_to == 1) {
		float y = dot(rgb, LUMA);
		outc = rgb + vec3(shape(y) - y);
	} else {
		outc = vec3(shape(rgb.r), shape(rgb.g), shape(rgb.b));
	}
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
