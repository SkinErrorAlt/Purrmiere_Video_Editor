shader_type canvas_item;
render_mode blend_disabled;

uniform float threshold : hint_range(0.0, 1.0) = 0.5;
uniform int mode : hint_range(0, 1) = 0;
uniform float smoothness : hint_range(0.0, 1.0) = 0.1;
uniform float mix_back : hint_range(0.0, 1.0) = 0.0;
uniform bool flip_darks = false;

vec3 rgb_to_ycc(vec3 c) {
	float y = dot(c, vec3(0.2126, 0.7152, 0.0722));
	return vec3(y, (c.b - y) / 1.8556, (c.r - y) / 1.5748);
}

vec3 ycc_to_rgb(vec3 v) {
	float r = v.x + 1.5748 * v.z;
	float b = v.x + 1.8556 * v.y;
	float g = (v.x - 0.2126 * r - 0.0722 * b) / 0.7152;
	return vec3(r, g, b);
}

float flip_weight(float x) {
	float s = max(smoothness, 0.001) * 0.5;
	float w = smoothstep(threshold - s, threshold + s, x);
	return flip_darks ? 1.0 - w : w;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 solar;
	if (mode == 1) {
		vec3 w = vec3(flip_weight(rgb.r), flip_weight(rgb.g), flip_weight(rgb.b));
		solar = mix(rgb, 1.0 - rgb, w);
	} else {
		vec3 ycc = rgb_to_ycc(rgb);
		float w = flip_weight(ycc.x);
		ycc.x = mix(ycc.x, 1.0 - ycc.x, w);
		solar = ycc_to_rgb(ycc);
	}
	rgb = mix(solar, rgb, clamp(mix_back, 0.0, 1.0));
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
