shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float z_blacks : hint_range(-2.0, 2.0) = 0.35;
uniform float z_deep : hint_range(-2.0, 2.0) = 0.5;
uniform float z_shadows : hint_range(-2.0, 2.0) = 0.45;
uniform float z_darks : hint_range(-2.0, 2.0) = 0.25;
uniform float z_mids : hint_range(-2.0, 2.0) = 0.0;
uniform float z_lights : hint_range(-2.0, 2.0) = -0.15;
uniform float z_whites : hint_range(-2.0, 2.0) = -0.3;
uniform bool show_zones = false;

vec3 to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_display(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

float zone_value(int i) {
	if (i == 0) {
		return z_blacks;
	}
	if (i == 1) {
		return z_deep;
	}
	if (i == 2) {
		return z_shadows;
	}
	if (i == 3) {
		return z_darks;
	}
	if (i == 4) {
		return z_mids;
	}
	if (i == 5) {
		return z_lights;
	}
	return z_whites;
}

void fragment() {
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float ev = clamp(texture(TEXTURE, UV).r * 10.0 - 10.0, -7.0, 0.5);
	float sum = 0.0;
	float wsum = 0.0;
	for (int i = 0; i < 7; i++) {
		float d = ev - float(i - 6);
		float w = exp(-d * d / 0.72);
		sum += zone_value(i) * w;
		wsum += w;
	}
	float stops = sum / max(wsum, 0.000001);
	if (show_zones) {
		float z = clamp(floor(ev + 6.5), 0.0, 6.0) / 6.0;
		vec3 map = mix(vec3(0.1, 0.15, 0.55), vec3(0.95, 0.85, 0.3), z) * (0.35 + 0.65 * z);
		COLOR = vec4(map * a, a);
	} else {
		vec3 lin = to_linear(rgb) * exp2(stops);
		COLOR = vec4(to_display(lin) * a, a);
	}
}
